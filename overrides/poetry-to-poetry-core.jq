# replace poetry.masonry.api with poetry.core.masonry.api if it's the build backend
(.["build-system"]["build-backend"] |= (select(. == "poetry.masonry.api") |= "poetry.core.masonry.api")) |
# replace build-system.requires with poetry-core if it's poetry
(.["build-system"]["requires"] |= map(if test("^\\s*poetry\\s*(>=|<=|==|!=|~=)\\s*([0-9]|\\.)*") then "poetry-core" else . end))
