module AwsServer

  def get_cost_per_month params
    cost = ProductType.find_by_name(params[:product][:product_type]).cost_per_month
  end
  
  def get_value
    value = product_type
  end

  private

  def destroy_server
    ec2 = AWS::EC2.new(access_key_id: AppConfig.cloud[:creds][:access_key], secret_access_key: AppConfig.cloud[:creds][:secret_token])
    response = ec2.client.terminate_instances({instance_ids: [product_id]})
    response[:instances_set].first[:current_state][:name] == "shutting-down" ? "valid" : "invalid"
  end

  def launch_server
    begin
      ec2 = AWS::EC2.new(access_key_id: AppConfig.cloud[:creds][:access_key], secret_access_key: AppConfig.cloud[:creds][:secret_token])
      response = ec2.instances.create(image_id: image_id, instance_type: product_type, key_name: "mops_master_key")
      ec2.client.create_tags(resources: [response.id], tags: [{ key: 'Name', value: "Mops_Instance_#{id}" }, { key: 'Internal_name', value: name }])
      sleep 60
      description = ec2.client.describe_instances({instance_ids: [response.id]})
      instances_set = description.reservation_set.map(&:instances_set).flatten!
      dns_name = instances_set.first.dns_name
      cost = ProductType.find_by_name(product_type)[:cost_per_month].to_s
      update_attributes({product_id: response.id, launch_time: DateTime.now, cost: cost, dns_name: dns_name})
    rescue
      false
    end
  end

end