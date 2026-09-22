let
  realm = "\${data.keycloak_realm.scottylabs.id}";
  federation = "\${keycloak_ldap_user_federation.cmu.id}";

  # read-only LDAP attribute -> user attribute
  attrMapper =
    {
      name,
      user,
      ldap,
      mandatory ? false,
      alwaysRead ? true,
    }:
    {
      realm_id = realm;
      ldap_user_federation_id = federation;
      inherit name;
      user_model_attribute = user;
      ldap_attribute = ldap;
      read_only = true;
      always_read_value_from_ldap = alwaysRead;
      is_mandatory_in_ldap = mandatory;
    };
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        data.vault_kv_secret_v2.keycloak_ldap = {
          mount = "secret";
          name = "infra/keycloak-ldap";
        };

        resource.keycloak_ldap_user_federation.cmu = {
          realm_id = realm;
          name = "CMU LDAP";
          vendor = "AD";
          edit_mode = "UNSYNCED";
          connection_url = "ldaps://ldap.cmu.edu";
          use_truststore_spi = "ALWAYS";
          connection_pooling = true;
          bind_dn = "uid=scottylabs-svc,ou=andrewperson,dc=andrew,dc=cmu,dc=edu";
          bind_credential = "\${data.vault_kv_secret_v2.keycloak_ldap.data[\"BIND_CREDENTIAL\"]}";
          users_dn = "ou=andrewperson,dc=andrew,dc=cmu,dc=edu";
          user_object_classes = [
            "cmuAccountPerson"
            "inetOrgPerson"
          ];
          custom_user_search_filter = "(objectClass=cmuAccountPerson)";
          username_ldap_attribute = "uid";
          rdn_ldap_attribute = "uid";
          uuid_ldap_attribute = "guid";
          krb_principal_attribute = "userPrincipalName";
          trust_email = true;
          batch_size_for_sync = 1;
          changed_sync_period = 3600;
        };

        resource.keycloak_ldap_user_attribute_mapper = {
          cmu_ldap_username = attrMapper {
            name = "username";
            user = "username";
            ldap = "uid";
            mandatory = true;
          };
          cmu_ldap_email = attrMapper {
            name = "email";
            user = "email";
            ldap = "mail";
            mandatory = true;
          };
          cmu_ldap_full_email = attrMapper {
            name = "full email";
            user = "fullEmail";
            ldap = "eduPersonPrincipalName";
            mandatory = true;
          };
          cmu_ldap_first_name = attrMapper {
            name = "first name";
            user = "firstName";
            ldap = "givenName";
          };
          cmu_ldap_middle_name = attrMapper {
            name = "middle name";
            user = "middleName";
            ldap = "cmuMiddleName";
          };
          cmu_ldap_last_name = attrMapper {
            name = "last name";
            user = "lastName";
            ldap = "sn";
          };
          cmu_ldap_full_name = attrMapper {
            name = "full name";
            user = "fullName";
            ldap = "cn";
            mandatory = true;
          };
          cmu_ldap_display_name = attrMapper {
            name = "display name";
            user = "displayName";
            ldap = "displayName";
            mandatory = true;
          };
          cmu_ldap_status = attrMapper {
            name = "status";
            user = "status";
            ldap = "status";
            mandatory = true;
          };
          cmu_ldap_affiliations = attrMapper {
            name = "affiliations";
            user = "affiliations";
            ldap = "eduPersonAffiliation";
          };
          cmu_ldap_primary_affiliation = attrMapper {
            name = "primary affiliation";
            user = "primaryAffiliation";
            ldap = "eduPersonPrimaryAffiliation";
          };
          cmu_ldap_class = attrMapper {
            name = "class";
            user = "class";
            ldap = "cmuStudentClass";
          };
          cmu_ldap_level = attrMapper {
            name = "level";
            user = "level";
            ldap = "cmuStudentLevel";
          };
          cmu_ldap_colleges = attrMapper {
            name = "colleges";
            user = "colleges";
            ldap = "eduPersonSchoolCollegeName";
          };
          cmu_ldap_departments = attrMapper {
            name = "departments";
            user = "departments";
            ldap = "cmuDepartment";
          };
          cmu_ldap_orcid = attrMapper {
            name = "orcid";
            user = "orcid";
            ldap = "eduPersonOrcid";
          };
          cmu_ldap_creation_date = attrMapper {
            name = "creation date";
            user = "createTimestamp";
            ldap = "whenCreated";
            alwaysRead = false;
          };
          cmu_ldap_modify_date = attrMapper {
            name = "modify date";
            user = "modifyTimestamp";
            ldap = "whenChanged";
            alwaysRead = false;
          };
        };

        resource.keycloak_ldap_msad_user_account_control_mapper.cmu_ldap_msad = {
          realm_id = realm;
          ldap_user_federation_id = federation;
          name = "MSAD account controls";
        };

        # no dedicated provider resource for this mapper type
        resource.keycloak_ldap_custom_mapper.cmu_ldap_kerberos_principal = {
          realm_id = realm;
          ldap_user_federation_id = federation;
          name = "Kerberos principal attribute mapper";
          provider_id = "kerberos-principal-attribute-mapper";
          provider_type = "org.keycloak.storage.ldap.mappers.LDAPStorageMapper";
        };
      }
    ];
  };
}
