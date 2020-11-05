# docker-gs-base
Base Docker image for GeoServer to be used as a template. The image built using Dockerfile contained in this repository is not meant to be used directly to run GeoServer but as a parent image for actual GeoServer images.
Most of the Dockerfile statements consist of `ONBUILD` actions that are triggered at children images build time.

## How to build it
Dockerfile accepts a few arguments at build time that define the base image to build from:
- `BASE_IMAGE_NAME` defaults to `tomcat` [Apache Tomcat official Docker Image](https://hub.docker.com/_/tomcat/)
- `BASE_IMAGE_TAG`  defaults to `latest`

For instance
`docker build --build-arg "BASE_IMAGE_TAG=7.0-jre8"`
 builds an image based on official Apache Tomcat at tag `7.0-jre8` ( Tomcat version 7.0 and Java JRE version 8 )

## How to use it
As stated above the image is not meant to run directly but as a template for other Docker images. Take a looks at [this](https://github.com/geosolutions-it/docker-geoserver/blob/master/Dockerfile) Dockerfile for an example of child image.
The actual usefulness of this Docker image becomes evident at children images build time where, thanks to the above mentioned `ONBUILD` statements, various aspects of final GeoServer container can be customized.

Take a look at [this](https://github.com/geosolutions-it/docker-geoserver/blob/master/Dockerfile) child image documentation or the corresponding [Jenkins Job that builds it](http://build.geo-solutions.it/jenkins/view/Docker/job/Docker-GeoServer/) for more information, usage example and an actual [GeoServer container ready to use](https://hub.docker.com/r/geosolutionsit/geoserver/).
