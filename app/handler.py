from greeting import greet


def handler(event):
    name = (event.get("input") or {}).get("name", "world")
    return {"message": greet(name), "source": __file__, "event": event}
