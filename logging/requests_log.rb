$requests = $mongo.collection('requests') #track http requests
ONE_HOUR_IN_SECONDS = 3600
$requests.ensure_index('created_at', expire_after: ONE_HOUR_IN_SECONDS*24*7*2) rescue nil
def log_request(data)
  data = data.just(:time_took)
  data = data.merge({username: cusername, user_id: cuid, path: request_path, params: _params})
  $requests.add(data)
end