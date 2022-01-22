cd(@__DIR__)
using Pkg
Pkg.activate(".")
Pkg.instantiate()

##
using CSV, DataFrames, Pipe, Statistics, ProgressMeter

##
try
    mkdir("tmp")
catch e
end
##

try
    mkdir("data")
catch e
end

##

languagesF = "data/languages.csv"
formsF = "data/forms.csv"

!(isfile(languagesF) && isfile(formsF)) && begin
    asjpZip = download(
        "https://zenodo.org/record/3843469/files/lexibank/asjp-v19.1.zip",
        "tmp/asjp-19.1.zip",
    )
    run(`unzip -o $asjpZip -d tmp/`)
    cp("tmp/lexibank-asjp-0c18d44/cldf/forms.csv", formsF)
    cp("tmp/lexibank-asjp-0c18d44/cldf/languages.csv", languagesF)
    for f in readdir("tmp")
        rm("tmp/" * f, recursive = true)
    end
end
##
forms = CSV.read(formsF, DataFrame)
languages = CSV.read(languagesF, DataFrame)

dropmissing!(
    languages,
    [
        :classification_wals,
        :classification_ethnologue,
        :classification_glottolog
    ]
)

##

function cleanASJP(word)
    @pipe word |>
          replace(_, r"[ \*~\"]" => "") |>
          replace(_, r"(.)(.)(.)\$" => s"\2")
end

##

languages[!, :longname] = @pipe languages |>
                                zip(_.classification_wals, _.Name) |>
                                join.(_, ".") |>
                                replace.(_, "-" => "_")

forms[!, :simplified] = cleanASJP.(forms.Value)

languages = languages[.!occursin.("Oth.", languages.classification_wals), :]

conceptCoverage = @pipe forms |>
                        unique(_, [:Language_ID, :gloss_in_source]) |>
                        groupby(_, :gloss_in_source) |>
                        combine(nrow, _) |>
                        sort(_, :nrow, rev = true)

concepts = conceptCoverage.gloss_in_source[1:40]


forms40 = forms[map(x -> x ∈ concepts, forms.gloss_in_source), :]

languageCoverage = @pipe forms40 |>
                         unique(_, [:Language_ID, :gloss_in_source]) |>
                         groupby(_, :Language_ID) |>
                         combine(nrow, _) |>
                         sort(_, :nrow, rev = true)

doculects = languageCoverage.Language_ID[languageCoverage.nrow.>=30]

forms40 = forms40[map(x -> x ∈ doculects, forms40.Language_ID), :]

##


asjpLong = innerjoin(
    forms40,
    languages[:, [:Name, :longname]],
    on = :Language_ID => :Name,
)

asjpLong = asjpLong[.!occursin.("PROTO", asjpLong.Language_ID), :]


##

taxa = unique(asjpLong.Language_ID)

##

filter!(
    x -> x.Name ∈ taxa,
    languages,
)

##

select!(languages, [:Name, :Longitude, :Latitude])


##


global vowels = ['a', 'e', 'E', '3', 'i', 'o', 'u']

function isVowel(c::Char)
    c ∈ vowels
end

##

function l2cv_ratio(
    l::String,
    data=asjpLong
) 
    s = @pipe asjpLong |>
        filter(x -> x.Language_ID == l, _) |>
        select(_, :simplified) |>
        Array |> 
        vec |>
        join
    s_split = first.(split(s, ""))
    nVowels = isVowel.(s_split) |> sum
    nConsonants = size(s_split)[1] - nVowels
    nConsonants / nVowels
end

##


insertcols!(
    languages, 
    :cvRatio => zeros(length(taxa))
)

##

@showprogress for i in 1:size(languages, 1)
    languages[i,:cvRatio] = l2cv_ratio(languages.Name[i])
end

##

languages |> CSV.write("data/asjp_cvRatio.csv")