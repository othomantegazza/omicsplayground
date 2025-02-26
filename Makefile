BRANCH=`git rev-parse --abbrev-ref HEAD`  ## get active GIT branch
TAG=latest
ifeq ($(BRANCH),'develop')
  TAG=develop
endif

VERSION=`head -n1 VERSION`

run:
	R -e "shiny::runApp('shiny',launch.browser=TRUE,port=3838)"

run.headless:
	R -e "shiny::runApp('shiny',launch.browser=FALSE,port=3838,host='0.0.0.0')"

clean:
	rm `find -name '*~'`

show.branch:
	@echo $(BRANCH)

run.docker:
	@echo running docker $(TAG) at port 4000
	docker run --rm -p 4000:3838 bigomics/omicsplayground:$(TAG)

run.docker2:
	@echo running docker $(TAG) at port 4000
	docker run --rm -p 4000:3838 -v /home/kwee/Playground/pgx:/omicsplayground/data bigomics/omicsplayground:$(TAG)

run.docker3:
	@echo running docker $(TAG) at port 4000
	docker run --rm -p 4000:3838 -v /home/kwee/Playground/omicsplayground/data:/omicsplayground/data -v /home/kwee/Playground/omicsplayground-dev/libx:/omicsplayground/libx bigomics/omicsplayground:$(TAG)

build.docker:
	@echo building docker $(TAG) from branch $(BRANCH) 
	docker build --no-cache --build-arg BRANCH=$(BRANCH) \
		-f docker/Dockerfile \
	  	-t bigomics/omicsplayground:$(TAG) .
build.base:
	@echo building ubuntu BASE docker 
	docker build --no-cache \
		-f docker/Dockerfile.base \
	  	-t bigomics/omicsplayground:base .

build.ub:
	@echo building UB docker 
	docker build --no-cache -f docker/Dockerfile.ub -t ub .

bash.docker:
	@echo bash into docker $(TAG)
	docker run -it bigomics/omicsplayground:$(TAG) /bin/bash

tags:
	git tag -f -a $(VERSION) -m 'version $(VERSION)'
	git push && git push --tags
	docker tag bigomics/omicsplayground:$(TAG) bigomics/omicsplayground:$(VERSION)

push.latest: 
	docker push bigomics/omicsplayground:latest
	docker push bigomics/omicsplayground:$(VERSION)
