just to start 

docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build



just to stop 


docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down -v


