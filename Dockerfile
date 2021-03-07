FROM google/dart

ENV PORT 4040
EXPOSE $PORT

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["/usr/bin/dart", "/app/bin/main.dart"]
