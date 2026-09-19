FROM ruby:4.0.7

WORKDIR /app

RUN apt update && \
    apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev git -y

RUN gem install rails

CMD ["tail", "-f", "/dev/null"]