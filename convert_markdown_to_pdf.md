# Install Pandoc via miniconda
The pandoc version available on conda is newer (and better maintained than the packages on ubuntu). Best not to install the texlive-core from conda, because it may interfere with your existing texlive installation.

```
conda create -y -n pandoc python pip pandoc imagemagick
```

You may want to install the texlive distribution seperately on the system, if you prefer to have additional fonts (this will take some space, but it useful if you want to typeset any type of font).
```
sudo apt-get install texlive texlive-fonts-recommended texlive-fonts-extra
```

# Install Pandoc on ubuntu via package manager `apt`
```
sudo apt install pandoc texlive texlive-latex-recommended \
exlive-fonts-extra texlive-xetex texlive-luatex pandoc-citeproc etoolbox wkhtmltopdf
```

# Styles - Eisvogel
There are different style types available for converting Markdown (md) to PDF or Latex. Here we use [eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template).

In the following, we first clone the repository, and then copy it to the standard data dir of the pandoc distribution. Alternatively, you can copy this to ~/.pandoc/template

```
cd ~
mkdir github
cd github
git clone https://github.com/Wandmalfarbe/pandoc-latex-template.git
cd pandoc-latex-template
cd ~
mkdir -p .pandoc/templates
cp -rv github/pandoc-latex-template/eisvogel.tex .pandoc/templates/eisvogel.latex
```
## Correct Fonts when using eisvogel template
If you have a backtick in your source code, the eisvogel template may throw an error:
`[WARNING] Missing character: There is no ` in font SourceCodePro-Regular-tlf-ts1!`
You can fix this by calling pandoc with the option `--pdf-engine xelatex`, but this will result in a PDF that is non-standard. Better to change the font type to something else (see [here](https://github.com/Wandmalfarbe/pandoc-latex-template/issues/21)) using font `\usepackage{inconsolata}` around Line 513 in `~/.pandoc/templates/eisvogel.latex`


# Numbered Equations
For including numbered equationsin markdown documents, we rely on [pandoc-eqnos](https://github.com/tomduck/pandoc-eqnos). Install via:

```bash
conda activate pandoc
pip install pandoc-eqnos
```

This allows to include equations via `$$ y = mx + b $$ {#eq:id}` and then refer to it with `{@eq:id}`.

# Including Codes from files into Code blocks with [pandoc-include-code](https://github.com/owickstrom/pandoc-include-code)
We are using [pandoc-include-code](https://github.com/owickstrom/pandoc-include-code) to achieve this. Install `cabal`:

```
sudo apt install cabal-install
```
Then install with:
```bash
cabal install pandoc-include-code
```

Next, install the binary version from [https://github.com/owickstrom/pandoc-include-code/releases](https://github.com/owickstrom/pandoc-include-code/releases) and copy the file `pandoc-include-code` to `~/miniconda3/envs/pandoc/bin/`.

## Alternatively, install from source:
If you want to compile from source code, use the following instead (but not working yet, because some dependencies are missing):
```
mkdir ~/github
cd ~/github
git clone https://github.com/owickstrom/pandoc-include-code.git
cd pandoc-include-code
cabal configure
cabal install
```


# Convert Markdown to PDF

(or any other format, just change filename extension)
```bash
pandoc --number-sections --listings -H auto_linebreak_listings.tex \
    --filter pandoc-eqnos \
    --filter pandoc-include-code \
    --toc -V toc-title:"Table of Contents" \
    --variable papersize=a4paper \
    --highlight-style tango \
    --variable urlcolor=blue \
    -s SCI_Pozo_interpolation_GMT_GDAL.md -o SCI_Pozo_interpolation_GMT_GDAL.pdf \
    --template eisvogel    
```



Next, convert to lower resolution PDFs with GhostScript:

```bash
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=SCI_Pozo_interpolation_GMT_GDAL_ebook.pdf SCI_Pozo_interpolation_GMT_GDAL.pdf
#print conversion not working with the currently included figures:
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer -dNOPAUSE -dQUIET -dBATCH -sOutputFile=SCI_Pozo_interpolation_GMT_GDAL_print.pdf SCI_Pozo_interpolation_GMT_GDAL.pdf
```
