def app(environ, start_response):
    """Simplest possible application object"""
    data = b"Original\n"
    status = "200 OK"
    response_headers = [
        ("Content-type", "text/plain"),
        ("Content-Length", str(len(data))),
    ]
    start_response(status, response_headers)
    return iter([data])


def app_factory(global_config, **local_conf):
    return app
