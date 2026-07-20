{
  flake.modules.nixos.signage-01-firefox =
    { pkgs, lib, ... }:

    {

      # Lord Linus Torvalds, please forgive me.
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "firefox-bin"
          "firefox-bin-unwrapped"
        ];

      # Force wayland
      environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
      };

      programs.firefox = {
        enable = true;
        package = pkgs.firefox-bin;

        # System-wide Enterprise Policies
        policies = {
          DisableAppUpdate = true;
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DNSOverHTTPS = {
            Enabled = true;
            ProviderURL = "https://mozilla.cloudflare-dns.com/dns-query";
            Fallback = true;
            Locked = true;
          };

          # Scrollbar disable, it will still show given user input, but we assume there is no user input on kiosk
          Preferences = {
            "layout.testing.overlay-scrollbars.always-visible" = false;
          };
        };

        # System-wide Global Preferences
        preferences = {
          # startup settings
          "browser.aboutConfig.showWarning" = false;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;
          "browser.newtabpage.activity-stream.default.sites" = "";

          # recommendations
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;
          "browser.discovery.enabled" = false;

          # telemetry
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.server" = "data:,";
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "toolkit.telemetry.updatePing.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "toolkit.telemetry.coverage.opt-out" = true;
          "identity.fxaccounts.telemetry.clientAssociationPing.enabled" = false;
          "toolkit.coverage.opt-out" = true;
          "toolkit.coverage.endpoint.base" = "";

          # studies
          "app.shield.optoutstudies.enabled" = false;
          "app.normandy.enabled" = false;
          "app.normandy.api_url" = "";

          # crash reports
          "breakpad.reportURL" = "";
          "browser.tabs.crashReporting.sendReport" = false;

          # search bar
          "browser.urlbar.showSearchSuggestionsFirst" = false;
          "browser.urlbar.quicksuggest.enabled" = false;
          "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
          "browser.urlbar.suggest.quicksuggest.sponsored" = false;
          "browser.search.suggest.enabled" = false;
          "browser.search.suggest.enabled.private" = false;
          "browser.urlbar.suggest.bookmark" = false;
          "browser.urlbar.suggest.engines" = false;
          "browser.urlbar.suggest.history" = false;
          "browser.urlbar.suggest.openpage" = false;
          "browser.urlbar.suggest.quickactions" = false;
          "browser.urlbar.suggest.searches" = false;
          "browser.urlbar.suggest.topsites" = false;
          "browser.urlbar.trending.featureGate" = false;
          "browser.urlbar.addons.featureGate" = false;
          "browser.urlbar.amp.featureGate" = false;
          "browser.urlbar.mdn.featureGate" = false;
          "browser.urlbar.recentsearches.featureGate" = false;
          "browser.urlbar.weather.featureGate" = false;
          "browser.urlbar.wikipedia.featureGate" = false;
          "browser.urlbar.yelp.featureGate" = false;

          # passwords / forms
          "signon.rememberSignons" = false;
          "signon.autofillForms" = false;
          "signon.formlessCapture.enabled" = false;
          "browser.formfill.enable" = false;
          "extensions.formautofill.addresses.enabled" = false;
          "extensions.formautofill.creditCards.enabled" = false;

          # downloads
          "browser.download.manager.addToRecentDocs" = false;
          "browser.download.always_ask_before_handling_new_types" = true;

          # privacy
          "network.http.referer.XOriginTrimmingPolicy" = 2;

          # scrollbar removal related
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "svg.context-properties.content.enabled" = true;
          "sidebar.animation.enabled" = false;
        };
      };
    };
}
