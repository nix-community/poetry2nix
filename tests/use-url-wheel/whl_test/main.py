import de_core_news_sm
import sys


def main():
    nlp = de_core_news_sm.load()
    print(nlp("Dies ist ein Testsatz."))
