{ pkgs, ... }:
let
  python = pkgs.python3Packages;
  playwright = python.playwright;
  cloakbrowser = python.buildPythonPackage (finalAttrs: {
    pname = "cloakbrowser";
    version = "0.7.3";
    pyproject = true;
    src = pkgs.fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-pooJEBkRs0fYbF+7MQU+6hUJD+r2SPL1lvqXREjCTEE=";
    };
    build-system = [ python.hatchling ];
    dependencies = [
      python.cryptography
      python.httpx
      playwright
    ];
    # Validate imports without launching a browser or touching a user cache.
    doCheck = false;
    pythonImportsCheck = [ "cloakbrowser" ];
  });
  chromiumBrowsers = playwright.driver.selectBrowsers {
    withFirefox = false;
    withWebkit = false;
    # Default chromium.launch() uses the separate headless shell.
    withChromiumHeadlessShell = true;
  };
in
{
  my.pythonExtraPackages = [
    playwright
    cloakbrowser
  ];

  # Only the Python package is managed here, not CloakBrowser's separate binary.
  environment.variables.CLOAKBROWSER_AUTO_UPDATE = "false";

  # Use the browser revision from the same driver Python Playwright runs.
  # `python3 -m playwright install chromium` is not needed on these systems.
  environment.variables.PLAYWRIGHT_BROWSERS_PATH = "${chromiumBrowsers}";
}
