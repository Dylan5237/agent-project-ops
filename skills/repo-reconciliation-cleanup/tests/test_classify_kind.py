"""Pure mapping tests for classify KIND (no git required)."""


def kind(ahead: int, behind: int) -> str:
    if ahead == 0 and behind == 0:
        return "SAME"
    if ahead == 0 and behind > 0:
        return "ANCESTOR"
    if ahead > 0 and behind == 0:
        return "AHEAD"
    return "DIVERGED"


def test_matrix():
    assert kind(0, 0) == "SAME"
    assert kind(0, 5) == "ANCESTOR"
    assert kind(3, 0) == "AHEAD"
    assert kind(2, 4) == "DIVERGED"
