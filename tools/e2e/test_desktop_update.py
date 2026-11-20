#!/usr/bin/env python3
"""Exercise the packaged desktop update helper with real release archives.

The candidate package receives a temporary startup probe. No account data is
embedded. The probe proves that the helper launched the newly installed client.
"""

from __future__ import annotations

import argparse
import hashlib
import http.server
import json
import shutil
import subprocess
import sys
import threading
import time
import zipfile
from pathlib import Path


PROBE_MODULE = """Module
  name: zealot_update_e2e
  description: Temporary desktop update restart probe
  sandboxed: true
  autoload: true
  autoload-priority: 9998
  scripts: [ probe ]
  @onLoad: init()
"""
PROBE_SCRIPT = """function init()
  local version = g_app.getVersion()
  g_resources.writeFileContentsToWorkDir('zealot-update-restarted.txt', version .. '\\n')
  scheduleEvent(g_app.exit, 5000)
end
"""
FLOW_SCRIPT = """local requested = false
local delivered = false
local expectedUrl = __PACKAGE_URL__
local localUrl = __LOCAL_URL__
local releaseVersion = __VERSION__
local expectedSha = __SHA256__
local platform = __PLATFORM__
local architecture = __ARCHITECTURE__

local function record(stage)
  g_logger.info('[updater-e2e] ' .. stage)
  g_resources.writeFileContentsToWorkDir('zealot-update-flow-state.txt', stage .. '\\n')
end

function init()
  record('module loaded')
  local originalGetJSON = HTTP.getJSON
  local originalDownload = HTTP.download
  local originalDisplay = displayGeneralBox

  HTTP.getJSON = function(url, callback, timeout)
    if url == Services.clientUpdate then
      if delivered then return -1 end
      delivered = true
      record('version request intercepted')
      scheduleEvent(function()
        record('new version delivered current=' .. tostring(g_app.getVersion()) ..
          ' target=' .. releaseVersion .. ' os=' .. tostring(g_app.getOs()) ..
          ' arch=' .. tostring(g_app.getBuildArch()) ..
          ' desktop=' .. tostring(g_platform.isDesktop()) ..
          ' package=' .. platform .. '/' .. architecture)
        local ok, err = pcall(callback, { version = releaseVersion, packages = {
          [platform] = { [architecture] = { url = expectedUrl, sha256 = expectedSha } }
        } }, nil)
        if not ok then record('update callback error: ' .. tostring(err)) end
      end, 100)
      return -1
    end
    return originalGetJSON(url, callback, timeout)
  end

  HTTP.download = function(url, file, callback, progress)
    if url == expectedUrl then
      record('package download started')
      return originalDownload(localUrl, file, callback, progress)
    end
    return originalDownload(url, file, callback, progress)
  end

  displayGeneralBox = function(title, message, buttons, ...)
    local box = originalDisplay(title, message, buttons, ...)
    if title == tr('Client update available') and not requested then
      record('update prompt shown')
      requested = true
      scheduleEvent(function()
        for _, button in ipairs(buttons) do
          if button.text == tr('Update automatically') then
            record('automatic update selected')
            g_resources.writeFileContentsToWorkDir('zealot-update-clicked.txt', 'PASS\\n')
            button.callback()
            return
          end
        end
      end, 250)
    end
    return box
  end

  scheduleEvent(function()
    if not requested and ClientUpdate then
      record('checking update explicitly')
      ClientUpdate.check()
    end
  end, 3000)
end
"""


def run(*command: str, **kwargs) -> None:
    subprocess.run(command, check=True, **kwargs)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract(archive: Path, destination: Path, platform: str) -> Path:
    destination.mkdir(parents=True)
    if platform == "linux":
        run("tar", "-xzf", str(archive), "-C", str(destination), "--no-same-owner")
    elif platform == "macos":
        run("ditto", "-x", "-k", str(archive), str(destination))
    else:
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(destination)
    # The public Linux archive contains harmless empty top-level data/modules/mods
    # directories alongside the actual package root. Select by init.lua.
    roots = [entry for entry in destination.iterdir()
             if entry.is_dir() and (runtime_root(entry, platform) / "init.lua").is_file()]
    if len(roots) != 1:
        raise RuntimeError(f"Expected one package root in {archive}, found {len(roots)}")
    return roots[0]


def runtime_root(package: Path, platform: str) -> Path:
    return package / "Contents" / "Resources" if platform == "macos" else package


def executable(package: Path, platform: str) -> Path:
    if platform == "macos":
        return package / "Contents" / "MacOS" / "Zealot Client"
    if platform == "windows":
        return package / "Zealot Client.exe"
    return package / "zealot-client"


def inject_probe(package: Path, platform: str) -> None:
    module = runtime_root(package, platform) / "mods" / "zealot_update_e2e"
    module.mkdir(parents=True)
    (module / "zealot_update_e2e.otmod").write_text(PROBE_MODULE)
    (module / "probe.lua").write_text(PROBE_SCRIPT)
    if platform == "macos":
        run("codesign", "--force", "--deep", "--sign", "-", str(package))


def inject_update_flow(package: Path, platform: str, package_url: str,
                       local_url: str, version: str, digest: str, architecture: str) -> None:
    module = runtime_root(package, platform) / "mods" / "zealot_update_flow_e2e"
    module.mkdir(parents=True)
    (module / "zealot_update_flow_e2e.otmod").write_text(
        PROBE_MODULE.replace("zealot_update_e2e", "zealot_update_flow_e2e")
        .replace("scripts: [ probe ]", "scripts: [ flow ]")
        .replace("sandboxed: true", "sandboxed: false")
    )
    source = FLOW_SCRIPT
    values = {
        "__PACKAGE_URL__": package_url, "__LOCAL_URL__": local_url,
        "__VERSION__": version, "__SHA256__": digest,
        "__PLATFORM__": platform, "__ARCHITECTURE__": architecture,
    }
    for key, value in values.items():
        source = source.replace(key, json.dumps(value))
    (module / "flow.lua").write_text(source)
    if platform == "macos":
        run("codesign", "--force", "--deep", "--sign", "-", str(package))


def start_archive_server(archive: Path):
    class ArchiveHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/candidate":
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(archive.stat().st_size))
            self.end_headers()
            with archive.open("rb") as source:
                shutil.copyfileobj(source, self.wfile)

        def log_message(self, *_args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), ArchiveHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def package_candidate(package: Path, platform: str, work: Path) -> Path:
    archive = work / ("candidate.tar.gz" if platform == "linux" else "candidate.zip")
    if platform == "linux":
        run("tar", "-czf", str(archive), "-C", str(package.parent), package.name)
    elif platform == "macos":
        run("ditto", "-c", "-k", "--keepParent", str(package), str(archive))
    else:
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for file in package.rglob("*"):
                if file.is_file():
                    bundle.write(file, file.relative_to(package.parent))
    return archive


def invoke_helper(platform: str, old_runtime: Path, archive: Path,
                  target: Path, expected: str, log: Path) -> int:
    helper_source = old_runtime / "modules" / "client_update" / (
        "apply-windows.ps1" if platform == "windows" else
        "apply-macos.sh" if platform == "macos" else "apply-linux.sh"
    )
    if not helper_source.is_file():
        raise RuntimeError(f"Published client has no update helper: {helper_source}")
    # The client copies its helper to the user update directory before exiting.
    # Running it from inside the installation would lock the old folder on Windows.
    helper = archive.parent / helper_source.name
    shutil.copy2(helper_source, helper)
    command = (["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(helper),
                "-ClientPid", "999999", "-Archive", str(archive),
                "-WorkDir", str(old_runtime), "-ExpectedSha256", expected]
               if platform == "windows" else
               ["/bin/sh", str(helper), "999999", str(archive), str(old_runtime), expected])
    with log.open("a") as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                timeout=150, check=False)
    return result.returncode


def wait_for_restart(marker: Path, expected_version: str, timeout: int = 90) -> None:
    deadline = time.monotonic() + timeout
    started = time.monotonic()
    state_path = marker.with_name("zealot-update-flow-state.txt")
    while time.monotonic() < deadline:
        if marker.is_file():
            actual = marker.read_text().strip()
            if actual != expected_version:
                raise RuntimeError(f"Relaunched client version {actual}, expected {expected_version}")
            return
        if time.monotonic() - started > 45 and state_path.is_file():
            state = state_path.read_text().strip()
            if "package download started" not in state and "automatic update selected" not in state:
                raise RuntimeError(f"Update stalled before download: {state}")
        time.sleep(1)
    raise RuntimeError("Updated client did not launch and write its startup probe")


def write_failure_state(work: Path, target: Path, platform: str) -> None:
    locations = [target, *target.parent.glob(target.name + ".previous.*")]
    lines = []
    for location in locations:
        lines.append(f"Package: {location} exists={location.exists()}")
        root = runtime_root(location, platform)
        for filename in ("zealot-update-flow-state.txt", "zealot-update-clicked.txt",
                         "zealot-update-restarted.txt"):
            marker = root / filename
            if marker.is_file():
                lines.append(f"{filename}: {marker.read_text().strip()}")
    (work / "failure-state.log").write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=("linux", "macos", "windows"))
    parser.add_argument("--old-archive", required=True, type=Path)
    parser.add_argument("--new-archive", required=True, type=Path)
    parser.add_argument("--new-version", required=True)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--windows-opengl-dir", type=Path)
    args = parser.parse_args()

    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    target = extract(args.old_archive.resolve(), work / "installed", args.platform)
    candidate = extract(args.new_archive.resolve(), work / "candidate", args.platform)
    old_runtime = runtime_root(target, args.platform)
    if args.platform == "windows":
        if not args.windows_opengl_dir:
            raise RuntimeError("Windows software OpenGL directory is required")
        for name in ("opengl32.dll", "libgallium_wgl.dll"):
            source = args.windows_opengl_dir / name
            if not source.is_file():
                raise RuntimeError(f"Missing software OpenGL DLL: {source}")
            shutil.copy2(source, candidate / name)
            shutil.copy2(source, target / name)
    inject_probe(candidate, args.platform)
    archive = package_candidate(candidate, args.platform, work)
    server = start_archive_server(archive)
    architecture = "arm64" if "macos-arm64" in args.new_archive.name else "x86_64"
    package_url = ("https://github.com/Zealot-Server/otclient/releases/download/"
                   f"v{args.new_version}/{args.new_archive.name}")
    inject_update_flow(target, args.platform, package_url,
                       f"http://127.0.0.1:{server.server_port}/candidate",
                       args.new_version, sha256(archive), architecture)
    old_binary = sha256(executable(target, args.platform))
    new_binary = sha256(executable(candidate, args.platform))
    if old_binary == new_binary:
        raise RuntimeError("Candidate executable is identical to published baseline")

    # A corrupt package must leave the previous client runnable and unchanged.
    bad_log = work / "bad-checksum-runner.log"
    if invoke_helper(args.platform, old_runtime, archive, target, "0" * 64, bad_log) == 0:
        raise RuntimeError("Installer accepted an invalid package checksum")
    if sha256(executable(target, args.platform)) != old_binary:
        raise RuntimeError("Invalid package modified the existing installation")
    if list(target.parent.glob(target.name + ".previous.*")):
        raise RuntimeError("Invalid package created a previous-version backup")

    # Start the published client. Its temporary module receives update metadata,
    # chooses the real UI button, downloads over HTTP, then lets production Lua
    # verify the SHA256 and launch the packaged installer. The helper relaunches
    # the candidate, which writes the startup probe.
    launcher = (target / "run-zealot-client.sh" if args.platform == "linux"
                else executable(target, args.platform))
    with (work / "old-client.log").open("w") as client_log:
        old_client = subprocess.Popen([str(launcher)], cwd=work if args.platform == "macos" else target,
                                      stdout=client_log, stderr=subprocess.STDOUT)
        try:
            marker = runtime_root(target, args.platform) / "zealot-update-restarted.txt"
            wait_for_restart(marker, args.new_version, timeout=240)
            old_client.wait(timeout=30)
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            write_failure_state(work, target, args.platform)
            raise
        finally:
            if old_client.poll() is None:
                old_client.terminate()
            server.shutdown()
            server.server_close()
    if sha256(executable(target, args.platform)) != new_binary:
        raise RuntimeError("Updated executable does not match the candidate")
    backups = list(target.parent.glob(target.name + ".previous.*"))
    if len(backups) != 1 or sha256(executable(backups[0], args.platform)) != old_binary:
        raise RuntimeError("Original published client was not preserved as a backup")
    if not (runtime_root(backups[0], args.platform) / "zealot-update-clicked.txt").is_file():
        raise RuntimeError("Old client did not activate the automatic update UI button")
    print(f"PASS: {args.platform} rejected a corrupt package, downloaded and installed "
          f"the candidate through the client UI, restarted version {args.new_version}, "
          "and retained the original client")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError,
            subprocess.TimeoutExpired, zipfile.BadZipFile) as error:
        print(f"Desktop updater E2E failed: {error}", file=sys.stderr)
        sys.exit(1)
