import Pkg
foreach(Pkg.add, ["CSV", "ParserCombinator", "JSON"])
using ParserCombinator, JSON, CSV

# Start date
start_date = 1665408893

#  Change exchange rates if necessary
exchange_rates = Dict(
    "AMD" => 1,
    "€" => 400,
    "\$" => 400,
    "BTC" => 20000 * 400
)

# Parsing the currency
currency_parser = exchange_rates |> pairs |> collect |> x -> map(pair -> let name = pair[1], rate = pair[2]; (Equal(name) | Equal(" $name")) > _ -> rate end, x) |> x -> reduce((a, b) -> a | b, x)
# Parsing number (with optional k for kilo) and a direction (+ (default) /-/±)
sumparser = (e"±" | e"-" | (e"+" | e"" > _ -> "+")) + ((PFloat32() + ((e"k" > _ -> 1000) | (e"" > _ -> 1)) + currency_parser) > (*))

# Yah it works

map(x -> parse_one(x, sumparser), [
    "123k AMD"
    "-9\$"
])

# Extracting mentions
function get_mentions(text)
    let
        index = findfirst(x -> x isa Dict && x["type"] == "mention", text)
        isnothing(index) ? "anon" : text[index]["text"]
    end
end

function normalize_to_array(x); (x isa Array{Any} ? x : [x]) end

# Checks that it's a valid #costs message
function is_costs(msg)
    msg["type"] == "message" &&
    let text = normalize_to_array(msg["text"]), author = msg["from_id"], ts = parse(Int, msg["date_unixtime"])
        # I AM THE AUTHOR
        author == "user315069089" &&
        
        # Not expired
        ts > start_date &&
        
        # and there is a hashtag there 
        filter(x -> x isa Dict && x["text"] == "#costs" && x["type"] == "hashtag", text) |> length > 0
    end
end


x = JSON.parsefile("result.json")["messages"] |> 
    x -> filter(is_costs, x) |>
    x -> map(msg -> normalize_to_array(msg["text"]), x) |>
    x -> map(text -> (
            text[2] |> 
            strip |> 
            x -> parse_one(x, sumparser),
            get_mentions(text)
        ),
        x
    ) |>
    x -> filter(p -> p[1][1] in ["+", "±"], x) |>
    x -> map(p -> p[2] => p[1][2], x) |>
    x -> CSV.write("mow.csv", x, header=["Hooman", "Sum money"]) |>
    x -> x