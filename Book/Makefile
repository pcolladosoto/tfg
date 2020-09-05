# Makefile for compiling the End-of-degree project (TFG)

CHAPTERS = $(addprefix Chapters/Ch_, 1 ) # pipes dispatcher worker gatherer fifos)

# Trashy file formats
TRASH = *.aux *.ist *.log *.out *.sbl *.acn

all: main clean

dbg: main

# We need to run it twice for the refs and stuff to be picked up!
main: main.tex
	pdflatex -jobname $@ $<
	pdflatex -jobname $@ $<

.PHONY: clean clean_pdf

clean:
	rm -f $(TRASH)

clean_pdf:
	rm -f *.pdf
