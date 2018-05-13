$settings = $mongo.collection('settings')

SETTINGS_FIELDS = [:sampling_game_nrounds, :sampling_game_show_data]

$settings.update_id(:data,{}, upsert: true)
get '/settings' do
  protected!
  erb :settings, layout: :layout
end

post '/update_settings' do
  $settings.update_id(:data,pr)  
  flash.message = 'Settings Updated'
  redirect back
end

def get_setting(key)
  $settings.get(:data)[key] || 'missing'
end