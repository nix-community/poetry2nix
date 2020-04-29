  source $stdenv/setup
  echo "trying prediction first $predictedURL"
curl -L -k $predictedURL --output $out 
  if ! [ $? -ne 0 ]; then
          echo "prediction failed, asking PyPI's API"
          URL_FROM_API=$(curl -L -k "https://pypi.org/pypi/$pname/json" | jq -r ".releases.\"$version\"[] | select(.filename == \"$file\") | .url")
          echo "trying $URL_FROM_API"
          curl -k $URL_FROM_API --output $out
  fi
