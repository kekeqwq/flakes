{ config, pkgs, ... }:
{
  myuser.hm.programs.codex = {
    enable = true;

    # 默认就是 pkgs.codex，显式写出来方便以后覆盖版本
    package = pkgs.codex;

    settings = {
      approvals_reviewer = "user";

      # Mac B 默认仍然直接使用原生 OpenAI
      model = "gpt-5.6-luna";
      model_reasoning_effort = "medium";

      projects = {
        "/Users/keke" = {
          trust_level = "trusted";
        };
        "/Users/keke/Downloads/USB" = {
          trust_level = "trusted";
        };
        "/Users/keke/Repos/flakes" = {
          trust_level = "trusted";
        };


      };

      # Windows Surface 上运行的 OpenCodex
      model_providers.opencodex = {
        name = "OpenCodex on Surface";
        base_url = "http://surface:10100/v1";
        wire_api = "responses";
        requires_openai_auth = true;

        env_http_headers = {
          "x-opencodex-api-key" = "OPENCODEX_API_AUTH_TOKEN";
        };
      };
    };
  };
}
