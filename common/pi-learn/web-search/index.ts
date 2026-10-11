import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { Text } from "@mariozechner/pi-tui";
import * as fs from "node:fs";
import * as path from "node:path";

interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

interface StructuredSearchArgs {
  query?: string;
  exactPhrases?: string[];
  excludeTerms?: string[];
  site?: string;
  count?: number;
}

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

function authCandidates(): string[] {
  const home = process.env.HOME ?? "";
  const agentDir =
    process.env.PI_CODING_AGENT_DIR ??
    (home ? path.join(home, ".pi", "agent") : "");
  return [
    agentDir ? path.join(agentDir, "web-search-auth.json") : "",
    home ? path.join(home, ".pi", "agent", "web-search-auth.json") : "",
  ].filter(Boolean);
}

function braveKey(): string | null {
  const fromEnv = process.env.BRAVE_SEARCH_API_KEY?.trim();
  if (fromEnv) return fromEnv;
  for (const candidate of authCandidates()) {
    if (!fs.existsSync(candidate)) continue;
    try {
      const config = JSON.parse(fs.readFileSync(candidate, "utf-8"));
      const key = String(config.brave_search_api_key ?? "").trim();
      if (key) return key;
    } catch {
      /* try the next file */
    }
  }
  return null;
}

function stripWrappingQuotes(value: string): string {
  return value.length >= 2 && value.startsWith('"') && value.endsWith('"')
    ? value.slice(1, -1).trim()
    : value;
}

function cleanItems(values?: string[]): string[] {
  if (!values) return [];
  return values
    .map((value) => stripWrappingQuotes(value.trim().replace(/\s+/g, " ")))
    .filter(Boolean);
}

function cleanQuery(value?: string): string | undefined {
  if (typeof value !== "string") return undefined;
  const cleaned = value.trim().replace(/\s+/g, " ");
  return cleaned || undefined;
}

function normalizeSite(site?: string): string | undefined {
  if (typeof site !== "string") return undefined;
  let value = site
    .trim()
    .replace(/^site:/i, "")
    .trim();
  if (!value) return undefined;
  try {
    const candidate = /^[a-z]+:\/\//i.test(value) ? value : `https://${value}`;
    const url = new URL(candidate);
    if (url.hostname) value = url.hostname;
  } catch {
    /* keep the raw site string */
  }
  return value.replace(/\/+$/, "") || undefined;
}

function quoteForSearch(value: string): string {
  return `"${value.replace(/"/g, '\\"')}"`;
}

function buildSearchQuery(args: StructuredSearchArgs): string {
  const baseQuery = cleanQuery(args.query);
  const exactPhrases = cleanItems(args.exactPhrases);
  const excludeTerms = cleanItems(args.excludeTerms);
  const site = normalizeSite(args.site);
  if (!baseQuery && exactPhrases.length === 0) {
    throw new Error("At least one of 'query' or 'exactPhrases' is required.");
  }
  const parts: string[] = [];
  if (baseQuery) parts.push(baseQuery);
  for (const phrase of exactPhrases) parts.push(quoteForSearch(phrase));
  for (const term of excludeTerms) {
    parts.push(`-${term.includes(" ") ? quoteForSearch(term) : term}`);
  }
  if (site) parts.push(`site:${site}`);
  return parts.join(" ");
}

function decodeHtml(value: string): string {
  return value
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x2F;/g, "/")
    .replace(/\s+/g, " ")
    .trim();
}

function unwrapDuckDuckGoUrl(href: string): string {
  const absolute = href.startsWith("//") ? `https:${href}` : href;
  try {
    const url = new URL(absolute, "https://duckduckgo.com");
    return url.searchParams.get("uddg") ?? absolute;
  } catch {
    return absolute;
  }
}

async function searchDuckDuckGo(
  query: string,
  count: number,
  signal?: AbortSignal,
): Promise<SearchResult[]> {
  const url = new URL("https://html.duckduckgo.com/html/");
  url.searchParams.set("q", query);
  const response = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, Accept: "text/html" },
    signal,
  });
  if (!response.ok) {
    throw new Error(`DuckDuckGo HTML ${response.status}`);
  }
  const html = await response.text();
  if (/anomaly|captcha/i.test(html) && !html.includes("result__a")) {
    throw new Error(
      "DuckDuckGo blocked this search. Set BRAVE_SEARCH_API_KEY and retry.",
    );
  }
  const results: SearchResult[] = [];
  const pattern =
    /<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/g;
  for (const match of html.matchAll(pattern)) {
    const resultUrl = unwrapDuckDuckGoUrl(decodeHtml(match[1]));
    if (!resultUrl.startsWith("http")) continue;
    results.push({
      title: decodeHtml(match[2]) || resultUrl,
      url: resultUrl,
      snippet: decodeHtml(match[3]),
    });
    if (results.length >= count) break;
  }
  return results;
}

async function searchBrave(
  query: string,
  count: number,
  apiKey: string,
  signal?: AbortSignal,
): Promise<SearchResult[]> {
  const url = new URL("https://api.search.brave.com/res/v1/web/search");
  url.searchParams.set("q", query);
  url.searchParams.set("count", String(Math.min(count, 20)));
  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
      "X-Subscription-Token": apiKey,
    },
    signal,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Brave Search ${response.status}: ${body.slice(0, 200)}`);
  }
  const data = (await response.json()) as {
    web?: {
      results?: Array<{ title?: string; url?: string; description?: string }>;
    };
  };
  return (data.web?.results ?? [])
    .filter((item) => item.url)
    .slice(0, count)
    .map((item) => ({
      title: item.title || item.url || "",
      url: item.url || "",
      snippet: item.description || "",
    }));
}

function formatResults(results: SearchResult[]): string {
  if (results.length === 0) return "No results found.";
  return results
    .map(
      (result, index) =>
        `${index + 1}. ${result.title}\n   ${result.url}\n   ${result.snippet}`,
    )
    .join("\n\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the public web. Uses Brave Search when BRAVE_SEARCH_API_KEY or web-search-auth.json brave_search_api_key is set; otherwise uses DuckDuckGo HTML. Returns title, URL, and snippet.",
    promptSnippet:
      "Search the web via a query string plus optional exactPhrases, excludeTerms, and site. Use one tool call per search angle.",
    promptGuidelines: [
      "Use exactPhrases for exact phrase matching instead of embedding quote marks inside the main query string.",
      "Use one web_search tool call per search angle instead of batching multiple searches into one call.",
    ],
    parameters: Type.Object({
      query: Type.Optional(Type.String({ description: "Base search query." })),
      exactPhrases: Type.Optional(
        Type.Array(Type.String(), {
          description: "Exact phrases to quote in the query.",
        }),
      ),
      excludeTerms: Type.Optional(
        Type.Array(Type.String(), { description: "Terms to exclude." }),
      ),
      site: Type.Optional(
        Type.String({ description: "Optional site or domain restriction." }),
      ),
      count: Type.Optional(
        Type.Number({
          description: "Results to return, 1 to 10. Default 5.",
          minimum: 1,
          maximum: 10,
        }),
      ),
    }),
    async execute(_toolCallId, params: StructuredSearchArgs, signal) {
      const query = buildSearchQuery(params);
      const count = params.count ?? 5;
      const key = braveKey();
      const results = key
        ? await searchBrave(query, count, key, signal)
        : await searchDuckDuckGo(query, count, signal);
      return {
        content: [{ type: "text" as const, text: formatResults(results) }],
        details: {
          composedQuery: query,
          resultCount: results.length,
          backend: key ? "brave" : "duckduckgo",
        },
      };
    },
    renderCall(args, theme, context) {
      const text =
        (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
      try {
        const query = buildSearchQuery(args as StructuredSearchArgs);
        const display = query.length > 70 ? `${query.slice(0, 67)}...` : query;
        text.setText(
          theme.fg("toolTitle", theme.bold("search ")) +
            theme.fg("accent", `"${display}"`),
        );
      } catch {
        text.setText(
          theme.fg("toolTitle", theme.bold("search ")) +
            theme.fg("error", "(invalid query)"),
        );
      }
      return text;
    },
    renderResult(result, { expanded, isPartial }, theme, context) {
      const text =
        (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
      if (isPartial) {
        text.setText(theme.fg("warning", "Searching…"));
        return text;
      }
      if (context.isError) {
        text.setText(
          theme.fg(
            "error",
            result.content.find((item) => item.type === "text")?.text ||
              "Error",
          ),
        );
        return text;
      }
      const details = result.details as {
        resultCount?: number;
        composedQuery?: string;
        backend?: string;
      };
      const status = theme.fg(
        "success",
        `${details?.resultCount ?? 0} results via ${details?.backend ?? "web"}`,
      );
      if (!expanded) {
        text.setText(status);
        return text;
      }
      const content =
        result.content.find((item) => item.type === "text")?.text || "";
      text.setText([status, theme.fg("dim", content.slice(0, 500))].join("\n"));
      return text;
    },
  });
}
