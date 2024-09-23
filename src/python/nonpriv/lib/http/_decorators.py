ON_ACCESS_ATTR = "__on_access__"
PAGE_ATTR = "__page__"


def on_access(actual):
    setattr(actual, ON_ACCESS_ATTR, None)
    return actual


def route(path: str):
    def register(actual):
        setattr(actual, PAGE_ATTR, path)
        return actual

    return register
