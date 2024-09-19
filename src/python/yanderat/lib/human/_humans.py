from ._models import Human
from ..common.json_manager import JsonManager


class Manager:
    def __init__(self, filepath: str) -> None:
        self._humans: dict[str, Human] = {}
        self._json_manager: JsonManager = JsonManager(filepath, self._humans)

    @property
    def humans(self) -> dict[str, Human]:
        return self._humans

    def add(self, human: Human) -> None:
        if self.get_by_id(human.id) is not None:
            raise ValueError("Cannot add the human. The human already exists in the database.")
        self._humans[human.id] = human

    def update(self, human: Human) -> None:
        if self.get_by_id(human.id) is None:
            raise ValueError("Cannot update the human. The human doesn't exists in the database.")
        self._humans[human.id] = human

    def delete(self, human: Human) -> None:
        if self.get_by_id(human.id) is None:
            raise ValueError("The human doesn't exists in the database.")
        self._humans.pop(human.id)

    def save(self) -> None:
        self._json_manager.save()

    def get_by_id(self, id_: str) -> Human | None:
        return self._humans.get(id_)
