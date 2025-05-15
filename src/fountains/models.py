# author: katherine carbeck
# 14 may 2025
# WIP...

from dataclasses import dataclass

@dataclass
class Fountain:
    id: int
    name: str
    address: str
    latitude: float
    longitude: float
    geo_local_area: str
    # …and later fields for ratings, cleanliness, etc.
