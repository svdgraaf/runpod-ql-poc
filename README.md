# runpod-ql-poc

# building
Create a docker image first (this is build to run on a arm mac)

```
make build

# push to your own image, make sure docker is logged in and stuff
DOCKER_USER=username make push 
```

The default image is called `runpod-ql-poc`, you can override with `IMAGE`.

# setup
- Create a network volume in runpod
  o create S3 credentials, and export those:
    o `export AWS_ACCESS_KEY_ID=user_... AWS_SECRET_ACCESS_KEY=rps_...`
  o `DATACENTER=xyz NETWORK_VOLUME=abc make sync` will sync your files to your volume in the right spot
- Create an SLS worker (regular pod will also work)
- Set worker size to 1 (but it doesn't really matter tbh 🤷‍♂️)
- Set the image you build and uploaded to your dockerhub repo
- Set the environment variables
```
RUNPOD_APP_DIR=/runpod-volume/app
RUNPOD_HANDLER=handler.py:handler
RUNPOD_HOT_RELOAD=1
```
- Select your volume (it should mount at `/runpod-volume`, change the environment variable accordingly otherwise)
- ...
- Profit!

You should now be able to send a request to your pod and it will process whatever you had in the `app` directory. Make local changes, run `make sync` again