# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  require 'yaml'
  before_filter :authorize, :except => ["missed_appointments","virtual_art_register","cohort","select_cohort","login","national_id","filing_number","test", "load_cache", "update_defaulters", "defaulters", "height_weight_by_user", "cohort_patients", "cohort_debugger", "survival_analysis", "old_cohort", "cohort_outcomes", "cohort_start_reasons", "monthly_drug_quantities"]

  include ExceptionNotifiable

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button=false, patient_id = nil)
    render :partial => "shared/print_and_redirect",
           :locals => {:print_url => print_url, :redirect_url => redirect_url,
                       :message => message, :show_next_button => show_next_button,
                       :patient_id => patient_id}
  end

  def rescue_action_in_public(exception)
    # do something based on exception
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.warn(@message) if @message
    logger.warn(@backtrace) if @backtrace
    render :file => "#{RAILS_ROOT}/app/views/error/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    # do something based on exception
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.warn(@message) if @message
    logger.warn(@backtrace) if @backtrace
    render :file => "#{RAILS_ROOT}/app/views/error/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

#  def local_request?
#    false
#  end
  
  def local_request?
    ["127.0.0.1", "192.168.2.13", "192.168.5.184","192.168.5.124"].include?(request.remote_ip)
  end
 
  
  def authorize
    session[:current_action] = nil
    session[:current_controller] = nil
    unless action_name == "logout"
			session[:current_action] = action_name 
			session[:current_controller] = controller_name
      User.current_user = User.find(session[:user_id]) unless session[:user_id].nil?
    end
    if session[:user_id].nil?
      redirect_to(:controller => "user", :action => "login")
    end 
  end

  def new_encounter_by_name(type_name)
    return new_encounter(EncounterType.find_by_name(type_name))
  end
  
  def new_encounter_from_form(form)
    encounter = new_encounter(form.type_of_encounter)
    encounter.form = form
    return encounter
  end
  
  def new_encounter(encounter_type)
    return new_encounter_from_encounter_type_id(encounter_type.id)
  end

  def new_encounter_from_encounter_type_id(encounter_type_id)
    encounter = Encounter.new
# encounters track the actual encounter with a patient. They can be entered in retrospectively.
    encounter.encounter_type = encounter_type_id
    encounter.patient_id = session[:patient_id]

    encounter.provider_id = User.current_user.user_id

    if session[:encounter_datetime] 
      encounter.encounter_datetime = session[:encounter_datetime] 
    else
      encounter.encounter_datetime = Time.now
    end

    encounter.location_id = session[:encounter_location] if session[:encounter_location] # encounter_location gets set in the session if it is a transfer in
    return encounter
  end

  def estimate_outcome_date(last_visit_date,current_date,year="Unknown",month="Unknown",day="Unknown")
   return "#{year}-#{month}-15".to_date if day == "Unknown"
   if month == "Unknown"
     month_estimate = last_visit_date.to_time.month + (current_date.month - last_visit_date.to_time.month).div(2) 
   return "#{year}-#{month_estimate}-15".to_date 
   end
   if year == "Unknown"
     year_estimate = last_visit_date.to_time + ((current_date.to_time - last_visit_date.to_time).quo(2))
   return "#{year_estimate}".to_date 
   end  
  end

  # returns last date of previous num month from a_date 
  def subtract_months(a_date, num)
    (1..num).each{|i|
      a_date = a_date - a_date.day
    }
    return a_date
  end  

  def room_tasks(location)
    rooms_to_tasks_property = GlobalProperty.find_by_property('rooms_to_tasks')
    tasks = nil
    if rooms_to_tasks_property and location
      rooms_to_tasks_text = '{'+rooms_to_tasks_property.property_value+'}'
      rooms_to_tasks_hash = JSON.parse(rooms_to_tasks_text)
      tasks = rooms_to_tasks_hash[location].split(',') rescue nil
    end
    tasks
  end
end
