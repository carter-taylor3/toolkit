module Kenna
module Api
   class Client

    def version
      0
    end

    def initialize(api_token, api_host)
      @token = api_token
      @base_url = "https://#{api_host}"
    end

    def get_connectors
      _kenna_api_request(:get, "connectors")
    end

    def get_connector(connector_id)
      _kenna_api_request(:get, "connectors/#{connector_id}")
    end

    def get_connector_runs(connector_id)
      _kenna_api_request(:get, "connectors/#{connector_id}/connector_runs")
    end

    # TODO: add page and per_page params
    def get_asset_groups
      _kenna_api_request(:get, "asset_groups")
    end

    def get_asset_group(asset_group_id)
      _kenna_api_request(:get, "asset_groups/#{asset_group_id}")
    end

    def get_assets
      _kenna_api_request(:get, "assets")
    end

    def get_asset(asset_id)
      _kenna_api_request(:get, "assets/#{asset_id}")
    end

    def get_asset_tags(asset_id)
      _kenna_api_request(:get, "assets/#{asset_id}/tags")
    end

    def get_applications
      _kenna_api_request(:get, "applications")
    end

    def get_application(application_id)
      _kenna_api_request(:get, "applications/#{application_id}")
    end

    # TODO: add page and per_page params
    def get_fixes
      _kenna_api_request(:get, "fixes")
    end

    def get_fix(fix_id)
      _kenna_api_request(:get, "fixes/#{fix_id}")
    end

    def get_asset_group_fixes(asset_group_id)
      _kenna_api_request(:get, "asset_groups/#{asset_group_id}/fixes")
    end

    def get_scanner_vuln_details(vuln_id)
      _kenna_api_request(:get, "vulnerabilities/#{vuln_id}/scanner_vulnerabilities")
    end

    def get_asset_vulns(asset_id)
      _kenna_api_request(:get, "assets/#{asset_id}/vulnerabilities")
    end

    def get_users
      _kenna_api_request(:get, "users")
    end

    def get_user(user_id)
      _kenna_api_request(:get, "users/#{user_id}")
    end

    def get_roles
      _kenna_api_request(:get, "roles")
    end

    def get_role(role_id)
      _kenna_api_request(:get, "roles/#{role_id}")
    end

    def get_vulns
      _kenna_api_request(:get, "vulnerabilities")
    end

    def get_vuln(vuln_id)
      _kenna_api_request(:get, "vulnerabilities/#{vuln_id}")
    end

    def get_cve_ids
      _kenna_api_request(:get, "vulnerability_definitions/cve_identifiers")
    end

    # cve_id - CVE-2020-0601 as an example id to pass
    def get_cve_id(cve_id)
      _kenna_api_request(:get, "vulnerability_definitions/#{cve_id}")
    end

    def get_dashboard_groups
      _kenna_api_request(:get, "dashboard_groups")
    end

    def upload_to_connector(connector_id, filepath)
    
      max_retries = 3

      kenna_api_endpoint = "#{@base_url}/connectors"

      headers = {
        'content-type' => 'application/json', 
        'X-Risk-Token' => @token,
        'accept' => 'application/json'
      }
  
      connector_endpoint = "#{kenna_api_endpoint}/#{connector_id}/data_file?run=true"

      begin
        print_good "Sending request"
        query_response = RestClient::Request.execute(
          method: :post,
          url: connector_endpoint,
          headers: headers,
          payload: {
            multipart: true,
            file: File.open(filepath,"r")
          }
        )

        query_response_json = JSON.parse(query_response.body)
        print_good "Success!" if query_response_json.fetch("success")

        running = true

        connector_check_endpoint = "#{kenna_api_endpoint}/#{connector_id}"
        while running do
          print_good "Waiting for 30 seconds... "
          sleep(30)

          #print_good "Checking on connector status..."
          connector_check_response = RestClient::Request.execute(
            method: :get,
            url: connector_check_endpoint,
            headers: headers
          )

          connector_check_json = JSON.parse(connector_check_response)['connector']
          print_good "#{connector_check_json["name"]} connector running!" if connector_check_json["running"]

          # check our value to see if we need to keep going
          running = connector_check_json["running"]
        end  
      
      rescue RestClient::Exceptions::OpenTimeout => e 
        print_error "Timeout: #{e.message}..."
      rescue RestClient::UnprocessableEntity => e
        print_error "Unprocessable Entity: #{e.message}..."
      rescue RestClient::BadRequest => e
        print_error "Bad Request: #{e.message}... #{e}"
      rescue RestClient::Unauthorized => e
        print_error "Unauthorized: #{e.message}... #{e}"
      rescue RestClient::Exception  => e
        print_error "Unknown Exception: #{e}"

        retries ||= 0
        if retries < max_retries
          print_error "Retrying in 60s..."
          retries += 1
          sleep(60)
          retry

        else
         print_error "Max retries hit, failing with... #{e}"
         return
        end

      end

      print_good "Done!"
    end

    private

    def _kenna_api_request(method, resource, body=nil)

      headers = { 'X-Risk-Token': "#{@token}" }
      endpoint = "#{@base_url}/#{resource}"
      out = { method: "#{method}", resource: "#{resource}"} 

      if method == :get
        
        begin 
          results = RestClient.get endpoint, headers
        rescue RestClient::Forbidden => e
          out.merge!({status: "fail", message: "access denied", results: {} })
        end

      elsif method == :post

        begin 
          results = RestClient.post endpoint, body, headers
        rescue RestClient::Forbidden => e
          out.merge!({status: "fail", message: "access denied", results: {} })
        end
  
      else 
        # uknown method
        out.merge!({status: "fail", message: "unknown method", results: {} })
      end

      # parse up the results
      begin 
        parsed_results = JSON.parse(results.body)
        out.merge!({status: "success", results: parsed_results })
      rescue
        out.merge!({status: "fail", message: "error parsing", results: {} })
      end

    out 
    end


  end
end
end