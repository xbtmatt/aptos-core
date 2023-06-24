# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

import json

from common import TestError
from test_helpers import RunHelper
from test_results import test_case


@test_case
def test_move_publish(run_helper: RunHelper, test_name=None):
    # Prior to this function running the move/ directory was moved into the working
    # directory in the host, which is then mounted into the container. The CLI is
    # then run in this directory, meaning the move/ directory is in the same directory
    # as the CLI is run from. This is why we can just refer to the package dir starting
    # with move/ here.
    package_dir = f"move/cli-e2e-tests/{run_helper.base_network}"

    # Publish the module.
    run_helper.run_command(
        test_name,
        [
            "aptos",
            "move",
            "publish",
            "--assume-yes",
            "--package-dir",
            package_dir,
            "--named-addresses",
            f"addr={run_helper.get_account_info().account_address}",
        ],
    )

    # Get what modules exist on chain.
    response = run_helper.run_command(
        test_name,
        [
            "aptos",
            "account",
            "list",
            "--account",
            run_helper.get_account_info().account_address,
            "--query",
            "modules",
        ],
    )

    # Confirm that the module exists on chain.
    response = json.loads(response.stdout)
    for module in response["Result"]:
        if (
            module["abi"]["address"]
            == f"0x{run_helper.get_account_info().account_address}"
            and module["abi"]["name"] == "cli_e2e_tests"
        ):
            return

    raise TestError(
        "Module apparently published successfully but it could not be found on chain"
    )


@test_case
def test_move_compile(run_helper: RunHelper, test_name=None):
    package_dir = f"move/cli-e2e-tests/{run_helper.base_network}"
    account_info = run_helper.get_account_info()

    # Compile the module.
    response = run_helper.run_command(
        test_name,
        [
            "aptos",
            "move",
            "compile",
            "--package-dir",
            package_dir,
            "--named-addresses",
            f"addr={account_info.account_address}",
        ],
    )

    if f"{account_info.account_address}::cli_e2e_tests" not in response.stdout:
        raise TestError("Module did not compile successfully")


@test_case
def test_move_compile_script(run_helper: RunHelper, test_name=None):
    package_dir = f"move/cli-e2e-tests/{run_helper.base_network}"
    account_info = run_helper.get_account_info()

    # Compile the script.
    response = run_helper.run_command(
        test_name,
        [
            "aptos",
            "move",
            "compile-script",
            "--package-dir",
            package_dir,
            "--named-addresses",
            f"addr={account_info.account_address}",
        ],
    )

    if "script_hash" not in response.stdout:
        raise TestError("Script did not compile successfully")
