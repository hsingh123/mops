module DigitalOceanServer

  def get_cost_per_month params
    cost = SizeType.find_by_size_id(params[:product][:size_type]).cost_per_month
  end

  def get_value
    value = SizeType.find_by_size_id(size_type).name
  end

  private

  def launch_server
    set_digital_ocean
    begin
      ssh_key = Digitalocean::SshKey.create(name: "#{name}_#{id}", ssh_pub_key: public_ssh_key)
      response = Digitalocean::Droplet.create({name: name, size_id: size_type, image_id: image_id.to_i, 
                                               region_id: Hash[AppConfig.region_ids].key(image_id.to_i), 
                                               ssh_key_ids: ssh_key.ssh_key.id.to_s})
      sleep 15
      response1 = Digitalocean::Droplet.retrieve(response.droplet.id)
      update_attributes({product_id: response.droplet.id, launch_time: DateTime.now, cost: cost, dns_name: response1.droplet.ip_address})
    rescue
      false
    end
  end
  
  def destroy_server
    set_digital_ocean
    response = Digitalocean::Droplet.destroy(product_id.to_i)
    response.status == "OK" ? "valid" : "invalid"
  end

  def set_digital_ocean
    Digitalocean.client_id  = AppConfig.cloud[:creds][:access_key]
    Digitalocean.api_key    = AppConfig.cloud[:creds][:secret_token]
  end

end