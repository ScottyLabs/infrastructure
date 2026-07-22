{
  flake.modules.terranix.s3-state = {
    terraform.backend.s3 = {
      bucket = "tofu-state";
      endpoints.s3 = "http://127.0.0.1:3900";
      region = "us-east-1";
      use_path_style = true;
      skip_credentials_validation = true;
      skip_requesting_account_id = true;
      skip_metadata_api_check = true;
      skip_region_validation = true;
    };
  };
}
