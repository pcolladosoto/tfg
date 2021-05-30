# Makefile for compiling the End-of-degree project (TFG)

CHAPTERS = $(addprefix Chapters/Ch_, 1 2 3)

# Trashy file formats
TRASH = *.aux *.ist *.log *.out *.sbl *.acn *.lol *.lot *.toc *.lof

# LaTeX compiler flags
FLAGS = -shell-escape

all: main clean

dbg: main

# We need to run it twice for the refs and stuff to be picked up!
main: main.tex
	pdflatex $(FLAGS) -jobname $@ $<
	pdflatex $(FLAGS) -jobname $@ $<

.PHONY: clean clean_pdf

clean:
	rm -f $(TRASH)

clean_pdf:
	rm -f *.pdf
