class ProductsController < ApplicationController

  respond_to :html
  skip_before_action :authenticate_user!, only: [:transaction_details]

  def index
    respond_with @products = current_user.products.where(web_name: AppConfig.cloud[:name]).order('launch_time DESC')
  end

  def show
    if params[:cm]
      params_id = params[:cm]
      flash[:notice] = "Your Transaction is Completed. Thank You for Joining. You will be notified with the details after successful launch of your instance. "
    else
      params_id = params[:id]
    end
    @product = current_user.products.find(params_id)
    @subscriptions = @product.subscriptions if @product
    respond_with @product, @subscriptions
  end

  def new
    respond_with @product = current_user.products.new
  end

  def create
    Product.transaction do
      @product = current_user.products.create(product_params)
      type = AppConfig.cloud[:name]
      cost = @product.get_cost_per_month(params)
      @product.update_attributes(web_name: type, cost: cost, status: 'pending')
      paypal_url = @product.paypal_url
      if paypal_url
        redirect_to paypal_url
      else
        redirect_to :back
      end
    end
  end

  def destroy
    product = Product.find(params[:id])
    if product.profileId && product.product_id

      response = product.send(:destroy_server)
      if response == "valid"
        ppr = PayPal::Recurring.new(:profile_id => product.profileId)
        ppr.cancel
        product.update_attributes(status: 'terminated')
        subscription = Subscription.where(product_id: product.id, status: "active")
        subscription.first.update_attributes(status: "expired") unless subscription.empty?
        flash[:notice] = "Server Destroyed Sucessfully."
      else
        flash[:error] = "Some error while destroying Server. Try again."
      end
    end
    redirect_to :back
  end

  def transaction_details
    product = Product.find(params[:custom])
    Product.transaction do 
      if params[:txn_type] == "subscr_signup"
        UserMailer.notification_email(product.user, product).deliver
        product.update_attributes(profileId: params[:subscr_id])
      elsif params[:txn_type] == "subscr_payment" && params[:payment_status] == 'Completed'
        subscript = product.user.subscriptions.where(sub_tran: params[:txn_id])
        unless !subscript.empty?
          unless product.product_id
            product_type, size_type = product[:product_type], product[:size_type]
            product.send(:launch_server)
            end_date = product.launch_time + 30.days
            notify_date = end_date - 7.days

            #create subscription
            product.user.subscriptions.create(
             web_type: product.web_name, image_id: product.image_id,
             product_type: product_type, instance_id: product.product_id, sub_tran: params[:txn_id],
             size_type: size_type, user_id: product.user.id, product_id: product.id,
             start_date: product.launch_time, end_date: end_date, notify_date: notify_date, status: 'active'
            )
            product.update_attributes(status: 'launched')
            UserMailer.transaction_email(product.user, product).deliver
          else
            end_date = Date.today + 30.days
            notify_date = end_date - 7.days

            #Expire old subscription 
            prev_sub = Subscription.where(product_id: product.id, status: "active")
            prev_sub.first.update_attributes(status: 'expired') unless prev_sub.empty?

            #create new subscription
            product.user.subscriptions.create(
              web_type: product.web_name, image_id: product.image_id, product_type: product_type,
              instance_id: product.product_id, sub_tran: params[:txn_id], size_type: size_type,
              user_id: product.user.id, product_id: product.id, start_date: product.launch_time,
              end_date: end_date, notify_date: notify_date, status: 'active'
            )
            product.update_attributes(status: 'launched')
            UserMailer.new_payment_email(product.user, product).deliver
          end
        end
      elsif params[:txn_type] == "subscr_cancel"
        UserMailer.delete_instance(product.user, product).deliver
      end
    end
    redirect_to servers_path
  end

  private
  def product_params
    params.require(:product).permit(:name, :product_type, :size_type, :image_id, :region_id)
  end

end
