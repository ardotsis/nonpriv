from dataclasses import fields


def from_dict[T](dataclass_type: type[T], data: dict) -> T:
    # Dataclass type: Human, Device ...

    field_types = {}
    for field in fields(dataclass_type):
        field_types[field.name] = field.type

    kwargs = {}
    for key, value in data.items():
        field_type = field_types[key]

        if isinstance(value, dict):
            nested_dataclass = from_dict(field_type, value)
            kwargs[key] = nested_dataclass
        else:
            kwargs[key] = value

    return dataclass_type(**kwargs)
