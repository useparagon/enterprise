#!/usr/bin/env node

// This script accepts a JSON file containing parameters and Paragon
// service information required to update the helm charts.

import { execSync } from "child_process";
import { existsSync, writeFileSync, readFileSync, mkdirSync } from "fs";
import { basename, resolve } from "path";

const SCRIPT_NAME = basename(process.argv[1]);
const USAGE = `Usage: node ${SCRIPT_NAME} <input-json> [workspace-directory]\n` +
  "  <input-json>          Path to a JSON file containing input parameters.\n" +
  "  [workspace-directory] Optional path to the repository root. Defaults to current directory.";

// Add the names of any services to ignore here.
// For any service NOT in this list, a corresponding helm chart
// must exist in the repo.
const ignoredServices = [
  'embassy',
  'prometheus-ecs-discovery',
  'redis-streams-exporter',
  'alb-log-parser',
];

/**
 * @typedef {Object} UpdateActionParams
 * @property {string} version
 * @property {string} platformEnv
 * @property {ChartInputs} inputs
 */

/**
 * @typedef {Object} ChartInputs
 * @property {ServiceInfo[]} services
 */

/**
 * @typedef {Object} ServiceInfo
 * @property {string} name
 * @property {string} category
 * @property {string[]} envKeys
 * @property {string[]} secretKeys
 */

const chartCategories = {
  monitoring: { subdir: 'paragon-monitoring' },
  logging: { subdir: 'paragon-logging' },
  onPrem: { subdir: 'paragon-onprem' },
}

async function main() {
  const { inputFilePath, workspaceDirectory } = verifyScriptArgs();
  process.cwd(workspaceDirectory);

  console.log(`Generating Helm charts using parameters from: ${inputFilePath}`);
  console.log(`Using workspace directory: ${resolve(workspaceDirectory)}`);
  console.log(`Code branch: ${getCurrentGitBranch()}`);

  const updateParams = readInputJSONFile(inputFilePath);
  const { version, platformEnv, inputs } = updateParams;
  console.log('Parsed input parameters:', { version, platformEnv, serviceCount: inputs.services.length });

  let failures = 0;
  inputs.services.forEach(service => {
    if (ignoredServices.includes(service.name)) {
      console.log(`Skipping ignored service: ${service.name}`);
      return;
    }
    if (!writeChartFixtures(service)) {
      failures += 1;
    }
  });

  if (failures > 0) {
    exitWithError(`Failed to write chart fixtures for ${failures} service(s).`);
  }

  console.log('Successfully wrote chart fixtures for all services.');
}

/**
 * Read and verify CLI arguments passed to the script.
 * @returns { inputFilePath: string, workspaceDirectory: string }
 */
function verifyScriptArgs() {
  const [inputFilePath, workspaceDirectory = '.'] = process.argv.slice(2);

  if (!inputFilePath) {
    exitWithUsageError('Missing required argument: <input.json>');
  }

  if (!existsSync(inputFilePath)) {
    exitWithUsageError(`Specified input file does not exist: ${inputFilePath}`);
  }

  if (!existsSync(workspaceDirectory)) {
    exitWithUsageError(`Workspace directory does not exist: ${workspaceDirectory}`);
  }

  if (!existsSync(`${workspaceDirectory}/charts/.`)) {
    exitWithUsageError(`The 'charts' directory was not found in ${workspaceDirectory}. Please pass the correct path to the repository root as the second argument.`);
  }

  return { inputFilePath, workspaceDirectory }
}

/**
 * @return {never}
 */
function exitWithError(message) {
  console.error(message);
  process.exit(1);
}

function exitWithUsageError(message) {
  exitWithError(message + "\n\n" + USAGE);
}

/**
 * @param {string} filePath 
 * @returns {UpdateActionParams}
 */
function readInputJSONFile(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch (error) {
    exitWithError(`Failed to read or parse input file: ${error.message}. Path: ${filePath}`);
  }
}

/**
 * @param {ServiceInfo} service
 * @return {boolean}
 */
function writeChartFixtures(service) {
  const { name: serviceName, category: serviceCategory, envKeys, secretKeys } = service;
  const chartCategory = getChartCategory(serviceName, serviceCategory);

  const flattenedService = {
    ...service,
    envKeys: Object.keys(envKeys).sort(),
    secretKeys: Object.keys(secretKeys).sort(),
  }

  // TODO: This is just a stub. Implement actual chart fixture writing logic here.
  console.log(`Writing chart fixtures for service: ${serviceName}`);
  const chartDirectory = `charts/${chartCategory.subdir}/charts/${serviceName}`;
  const chartYamlPath = `${chartDirectory}/Chart.yaml`;
  // e.g. charts/paragon-onprem/charts/zeus/Chart.yaml

  if (existsSync(chartYamlPath)) {
    console.log(`  Found chart directory: ${chartDirectory}`);
    mkdirSync(`${chartDirectory}/files`, { recursive: true });
    writeFileSync(`${chartDirectory}/files/service-inputs.json`, JSON.stringify(flattenedService, null, 2));
    return true;
  } else {
    console.error(`  Helm chart does not exist for service ${serviceName}!`);
    console.error(`  Expected path: ${chartYamlPath}`);
    console.error(`  Are you missing a helm chart for a newly-added service?`);
    console.error(`  Please create the chart or add the service to the ignore list in ${SCRIPT_NAME}.`);
    return false;
  }
}

function getChartCategory(serviceName, serviceCategory) {
  if (['openobserve', 'fluent-bit'].includes(serviceName)) {
    return chartCategories.logging;
  }
  if (serviceCategory === 'monitor') {
    return chartCategories.monitoring;
  }
  return chartCategories.onPrem;
}

function getCurrentGitBranch() {
  try {
    return execSync('git branch --show-current 2>/dev/null', { encoding: 'utf-8' }) || '(none)';
  } catch {
    return '(unavailable)';
  }
}

main().catch(error => {
  exitWithError(`Unexpected error: ${error.message} `);
});