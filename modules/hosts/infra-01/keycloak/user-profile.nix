let
  # Admin-only metadata attribute
  metaAttr = attrName: display: {
    name = attrName;
    display_name = display;
    permissions = [
      {
        view = [ "admin" ];
        edit = [ "admin" ];
      }
    ];
  };
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        resource.keycloak_realm_user_profile.scottylabs = {
          realm_id = "\${data.keycloak_realm.scottylabs.id}";
          attribute = [
            {
              name = "email";
              display_name = "\$\${email}";
              required_for_roles = [
                "admin"
                "user"
              ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
              validator = [
                { name = "email"; }
                {
                  name = "length";
                  config = {
                    max = "255";
                  };
                }
              ];
            }
            {
              name = "username";
              display_name = "\$\${username}";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
              validator = [
                {
                  name = "length";
                  config = {
                    min = "3";
                    max = "255";
                  };
                }
                { name = "username-prohibited-characters"; }
                { name = "up-username-not-idn-homograph"; }
              ];
            }
            {
              name = "fullEmail";
              display_name = "Full Email";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "firstName";
              display_name = "\$\${firstName}";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
              validator = [
                {
                  name = "length";
                  config = {
                    max = "255";
                  };
                }
                { name = "person-name-prohibited-characters"; }
              ];
            }
            {
              name = "middleName";
              display_name = "Middle Name";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "lastName";
              display_name = "\$\${lastName}";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
              validator = [
                {
                  name = "length";
                  config = {
                    max = "255";
                  };
                }
                { name = "person-name-prohibited-characters"; }
              ];
            }
            {
              name = "fullName";
              display_name = "Full Name";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "displayName";
              display_name = "Display Name";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "orcid";
              display_name = "ORCID";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "primaryAffiliation";
              display_name = "Primary Affiliation";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "affiliations";
              display_name = "Affiliations";
              multi_valued = true;
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "departments";
              display_name = "Departments";
              multi_valued = true;
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "colleges";
              display_name = "Colleges";
              multi_valued = true;
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "level";
              display_name = "Level";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "class";
              display_name = "Class";
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            {
              name = "status";
              display_name = "Status";
              required_for_roles = [ "user" ];
              permissions = [
                {
                  view = [
                    "admin"
                    "user"
                  ];
                  edit = [ "admin" ];
                }
              ];
            }
            (metaAttr "discord_id" "Discord ID")
            (metaAttr "discord_email" "Discord Email")
            (metaAttr "discord_username" "Discord Username")
            (metaAttr "discord_name" "Discord Global Name")
            (metaAttr "codeberg_id" "Codeberg ID")
            (metaAttr "codeberg_username" "Codeberg Username")
            (metaAttr "codeberg_email" "Codeberg Email")
            (metaAttr "codeberg_name" "Codeberg Name")
            (metaAttr "cmudev_id" "cmu.dev ID")
            (metaAttr "cmudev_username" "cmu.dev Username")
            (metaAttr "cmudev_email" "cmu.dev Email")
            (metaAttr "cmudev_name" "cmu.dev Name")
            (metaAttr "slack_id" "Slack ID")
            (metaAttr "slack_email" "Slack Email")
            (metaAttr "slack_name" "Slack Name")
            (metaAttr "google_id" "Google ID")
            (metaAttr "google_email" "Google Email")
            (metaAttr "google_name" "Google Name")
            (metaAttr "github_id" "GitHub ID")
            (metaAttr "github_username" "GitHub Username")
            (metaAttr "github_email" "GitHub Email")
            (metaAttr "github_name" "GitHub Name")
          ];
          group = [
            {
              name = "user-metadata";
              display_header = "User metadata";
              display_description = "Attributes, which refer to user metadata";
            }
          ];
        };
      }
    ];
  };
}
