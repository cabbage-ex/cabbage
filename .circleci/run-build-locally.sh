  #!/usr/bin/env bash
  curl --user eaa983a810796e8f34ffdac1fd517c8202ea2a9d: \
      --request POST \
      --form revision=a3aff0e5129f8fd7ef2a1bb6b2a702acf54b445c\
      --form config=@config.yml \
      --form notify=false \
          https://circleci.com/api/v1.1/project/github/cabbage-ex/cabbage/tree/master
