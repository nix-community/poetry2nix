import de_dep_news_trf


def main():
    nlp = de_dep_news_trf.load()
    print(nlp("Dies ist ein Testsatz."))
