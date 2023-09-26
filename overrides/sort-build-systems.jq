# Sort each entry in the top-level dictionary
.[] |= sort_by(
    if type == "string"
    then
        # Sort string overrides alphabetically
        .
    else
        # Sort entries with an `until` field above entries with a `from` field
        .from,
        .until
    end
)
