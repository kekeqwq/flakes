import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";

const id = "openai-account-3";
const name = "OpenAI (ChatGPT · account 3)";
const api = "openai-responses";
const baseUrl = "https://api.openai.com/v1";

export default function (pi: ExtensionAPI) {
  const native = builtinProviders().find((provider) => provider.id === "openai");
  const oauth = native?.auth?.oauth;
  if (!native || !oauth?.isSubscription) {
    throw new Error("This Pi build does not support native ChatGPT OAuth");
  }

  const models = native.getModels()
    .filter((model) => model.api === api && (!model.type || model.type === "chat"))
    .map((model) => ({ ...model, provider: id, baseUrl }));

  function requireRoute(model: { provider: string; api: string; baseUrl: string }, token?: string) {
    if (model.provider !== id || model.api !== api || model.baseUrl !== baseUrl) {
      throw new Error(`${id} requires the official OpenAI Responses endpoint`);
    }
    if (!token || token.startsWith("sk-")) {
      throw new Error(`${id} requires a ChatGPT subscription login`);
    }
  }

  // Register only the new alias. Pi retains ownership of login, storage and refresh.
  pi.registerProvider({
    id, name, baseUrl,
    getModels: () => models,
    getAllModels: () => models,
    auth: {
      oauth: {
        ...oauth,
        name,
        async toAuth(credential) {
          return { ...await oauth.toAuth(credential), baseUrl };
        },
      },
      // Do not fall back to metered OpenAI API credentials for this alias.
      apiKey: { name: "Unavailable (ChatGPT subscription only)", check: () => undefined, resolve: () => undefined },
    },
    // The native Responses adapter uses provider=openai to shape ChatGPT requests.
    stream(model, context, options) {
      requireRoute(model, options?.apiKey);
      return native.stream({ ...model, provider: "openai" }, context, options);
    },
    streamSimple(model, context, options) {
      requireRoute(model, options?.apiKey);
      return native.streamSimple({ ...model, provider: "openai" }, context, options);
    },
  });
}
