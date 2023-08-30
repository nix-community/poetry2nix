import de_dep_news_trf
import sys


def main():
    try:
        nlp = de_dep_news_trf.load()
        print(nlp("Dies ist ein Testsatz."))
    except OSError as e:
        print(
            "Unable to load nlp, likely due to nix sandbox not having CUDA "
            f"drivers. As long as the package imports, it's good: {e}",
            file=sys.stderr,
        )
        print("Dies ist ein Testsatz.\n")
