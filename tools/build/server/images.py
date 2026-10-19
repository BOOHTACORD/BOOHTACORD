"""Build and validate OCI artifacts with the exact source labels and attestations."""
import subprocess
from contextlib import nullcontext
from pathlib import Path
from urllib.parse import urlsplit
from tools.verify.oci.verify_oci import verify
from .layer_cache import LayerCache, namespace


def web_build_arguments(environment):
    flag = environment.get("VITE_RNNOISE_ENABLED", "true")
    if flag not in ("true", "false"):
        raise ValueError("VITE_RNNOISE_ENABLED must be true or false")
    descriptor = environment.get("VITE_SCREEN_SHARE_DESCRIPTOR_V1", "true")
    if descriptor not in ("true", "false"):
        raise ValueError("VITE_SCREEN_SHARE_DESCRIPTOR_V1 must be true or false")
    simulcast = environment.get("VITE_SCREEN_SHARE_BOUNDED_SIMULCAST", "false")
    if simulcast not in ("true", "false"):
        raise ValueError("VITE_SCREEN_SHARE_BOUNDED_SIMULCAST must be true or false")
    value = environment.get("VITE_PUBLIC_ORIGIN", "").strip()
    try:
        origin = urlsplit(value)
        port = origin.port
    except ValueError as error:
        raise ValueError("VITE_PUBLIC_ORIGIN must be a valid HTTPS origin") from error
    host = (origin.hostname or "").lower()
    if (origin.scheme.lower() != "https" or not host or origin.username or origin.password
            or port == 0 or origin.path not in ("", "/") or origin.query or origin.fragment):
        raise ValueError("VITE_PUBLIC_ORIGIN must be an HTTPS origin without credentials or a path")
    authority = f"[{host}]" if ":" in host else host
    if port and port != 443:
        authority += f":{port}"
    return ["--build-arg", "VITE_RNNOISE_ENABLED=" + flag,
            "--build-arg", "VITE_SCREEN_SHARE_DESCRIPTOR_V1=" + descriptor,
            "--build-arg", "VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=" + simulcast,
            "--build-arg", "VITE_PUBLIC_ORIGIN=https://" + authority]


def build(source, output, revision, source_hash, environment, *, metrics=None):
    receipts = {}
    measure=metrics.stage if metrics else lambda _:nullcontext()
    cache_root=environment.get('BOOHTACORD_SERVER_CACHE_ROOT')
    with (LayerCache(Path(cache_root)) if cache_root else nullcontext(None)) as cache:
        for service, context in (("api", "backend"), ("web", ".")):
            key=namespace(source,service)
            with measure(service+'_cache_prepare'):
                cache_args=cache.arguments(service,key) if cache else []
                if metrics and cache:metrics.value['cache']=cache.report
            tag = f"voice-platform-{service}:{revision}"
            archive = output / (service + ".oci.tar")
            with measure(service+'_build_export'):
                subprocess.run(["docker", "buildx", "build", "--platform", "linux/amd64",
                            "--label", f"org.opencontainers.image.revision={revision}",
                            "--label", f"org.voice-platform.source-archive-sha256={source_hash}",
                            "--sbom=true", "--provenance=mode=max,version=v0.2", "--load", "--tag", tag,
                            "--output", f"type=oci,dest={archive}",
                            '--build-arg', 'BOOHTACORD_CACHE_SCOPE='+key, *cache_args,
                            *( ["--file", str(source / "clients/web/Dockerfile"), *web_build_arguments(environment),
                                "--build-arg", "SOURCE_REVISION=" + revision] if service == "web" else []),
                            str(source / context)], env=environment, check=True)
            with measure(service+'_oci_verify'):
                image_id = subprocess.check_output(
                ["docker", "image", "inspect", "--format", "{{.Id}}", tag], text=True
            ).strip()
                receipts[service] = verify(archive, revision, source_hash, image_id)
            with measure(service+'_cache_publish'):
                if cache:cache.publish(service,key)
    return receipts
