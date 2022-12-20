import pytest


def test_simple():
    with pytest.raises(ImportError):
        import black  # noqa: F401
