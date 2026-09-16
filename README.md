# runpod-ql-poc

# building
You can use the public `svdgraafrunpod/runpod-ql-poc:dev` image, or build your own:

Create a docker image (this is build to run on a arm mac)

```
make build

# push to your own image, make sure docker is logged in and stuff
DOCKER_USER=username make push 
```

The default image is called `runpod-ql-poc`, you can override with `IMAGE`.

# setup
- Create a network volume in runpod
  - create S3 credentials, and export those:
    - `export AWS_ACCESS_KEY_ID=user_... AWS_SECRET_ACCESS_KEY=rps_...`
  - `DATACENTER=xyz NETWORK_VOLUME=abc make sync` will sync your files to your volume in the right spot
- Create an SLS worker (regular pod will also work)
- Set worker size to 1 (but it doesn't really matter tbh 🤷‍♂️)
- Set the image you build and uploaded to your dockerhub repo (or use `svdgraafrunpod/runpod-ql-poc:dev`)
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

# testing
```
runpodctl serverless run [endpoint-id] --input-file .test_input.json
```

For example:
```
runpodctl serverless run fzwndnr69imy1v --input-file test_input.json
waiting for job dc5e779d-967b-4b3e-ab03-b3bf798a64b7-e1: IN_QUEUE
job dc5e779d-967b-4b3e-ab03-b3bf798a64b7-e1: COMPLETED after 4s
{
  "delayTime": 3080,
  "executionTime": 141,
  "id": "dc5e779d-967b-4b3e-ab03-b3bf798a64b7-e1",
  "output": {
    "event": {
      "delayTime": 3080,
      "id": "dc5e779d-967b-4b3e-ab03-b3bf798a64b7-e1",
      "input": {
        "name": "sander"
      },
      "status": "IN_PROGRESS"
    },
    "message": "Hello hello sander!",
    "source": "/runpod-volume/app/handler.py"
  },
  "status": "COMPLETED",
  "workerId": "nys58hmkoes2g0"
}