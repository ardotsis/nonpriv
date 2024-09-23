from dataclasses import asdict

from ..common.from_dict import from_dict
from ..common.json_manager import JsonManager
from ._models import Human

type HumanDict = dict[str, any]


class Manager:
    def __init__(self, filepath: str) -> None:
        self._json_manager = JsonManager(filepath)
        self._humans_dict = self._json_manager.get()

    def add(self, human: Human) -> None:
        if self._humans_dict.get(human.id) is not None:
            raise ValueError(
                "Cannot add the human. The human already exists in the database.",
            )
        human_dict = self._human_to_dict(human)
        self._humans_dict[human.id] = human_dict
        self._json_manager.save()

    def delete(self, human: Human) -> None:
        if self._humans_dict.get(human.id) is None:
            raise ValueError("The human doesn't exists in the database.")
        self._humans_dict.pop(human.id)
        self._json_manager.save()

    @staticmethod
    def _human_to_dict(human: Human) -> HumanDict:
        human_dict = asdict(human)
        human_dict.pop("id")
        human_dict = {human.id: human_dict}
        return human_dict

    @staticmethod
    def _dict_to_human(id_, human_dict: HumanDict) -> Human:
        data = human_dict[id_]
        data["id"] = id_
        human = from_dict(Human, data)
        return human
