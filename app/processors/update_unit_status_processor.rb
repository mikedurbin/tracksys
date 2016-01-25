class UpdateUnitStatus < ApplicationProcessor

  subscribes_to :update_unit_status, {:ack=>'client', 'activemq.prefetchSize' => 1}

  def on_message(message)
    logger.debug "UpdateUnitStatusProcessor received: " + message

    # decode JSON message into Ruby hash
    hash = ActiveSupport::JSON.decode(message).symbolize_keys

    raise "Parameter 'unit_id' is required" if hash[:unit_id].blank?
    raise "Parameter 'unit_status is required" if hash[:unit_status].blank?
    raise "Parameter 'unit_status' is not a valid value" if Unit::UNIT_STATUSES.include?(hash[:unit_status])

    @messagable_id = hash[:unit_id]
    @messagable_type = "Unit"
    @workflow_type = AutomationMessage::WORKFLOW_TYPES_HASH.fetch(self.class.name.demodulize)

    @messagable.update_attribute(:unit_status, hash[:unit_status])
    on_success "Unit #{hash[:unit_id]} status changed to #{hash[:unit_status]}."

    # Update Unit's Order to 'approved' if all sibling Units are 'approved' or 'cancelled'
    order = @messagable.order
    if order.ready_to_approve?
      UpdateOrderStatusApproved.exec_now({ :order_id => order.id })
    end
  end
end
