extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for content_type in [false,true]:
		var request := HTTPRequest.new()
		request.use_threads = true
		request.timeout = 5
		root.add_child(request)
		var headers := PackedStringArray(["Authorization: Basic "+Marshalls.utf8_to_base64("office-preview-client-v1:")])
		if content_type: headers.append("Content-Type: application/json")
		request.request("http://127.0.0.1:17350/v2/account/authenticate/device?create=true",headers,HTTPClient.METHOD_POST,JSON.stringify({"id":"office-probe-"+Crypto.new().generate_random_bytes(16).hex_encode()}))
		var result = await request.request_completed
		print("HTTP_PROBE content_type=",content_type," result=",result[0]," status=",result[1]," bytes=",result[3].size())
		request.queue_free()
	quit()
