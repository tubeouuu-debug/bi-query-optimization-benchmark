/**
 * Tool: Google Apps Script - On-Demand Data Warehouse Sync Trigger
 * Author: Serena Nguyen
 * Description: Adds a custom UI button [⚡ DWH Operational Sync] on the Google Sheets menu bar.
 *              Allows Operations and Financial analysts to trigger backend pipeline syncs (via Airflow / AppFlow webhook)
 *              whenever off-cycle manual settlement adjustments or merchant status updates are posted.
 * 
 * Setup Instructions:
 * 1. In your operational Google Spreadsheet, go to: Extensions -> Apps Script.
 * 2. Paste this script into `Code.gs`.
 * 3. Replace the WEBHOOK_URL with your orchestration endpoint.
 * 4. Save and reload the spreadsheet.
 */

function onOpen() {
  var ui = SpreadsheetApp.getUi();
  ui.createMenu('⚡ DWH Operational Sync')
    .addItem('Trigger Sync to Data Warehouse', 'triggerDWHSync')
    .addToUi();
}

function triggerDWHSync() {
  var ui = SpreadsheetApp.getUi();
  
  // Prompt user for confirmation before firing pipeline
  var response = ui.alert(
    'Confirm Data Pipeline Refresh',
    'Do you want to trigger an on-demand sync from this sheet to the Data Warehouse?',
    ui.ButtonSet.YES_NO
  );
  
  if (response !== ui.Button.YES) {
    return;
  }
  
  // Orchestration Webhook Endpoint (e.g. Apache Airflow DAG Trigger or AWS AppFlow)
  var webhookUrl = "https://orchestrator.internal/api/v1/dags/sync_financial_settlement_mart/dagRuns";
  
  var payload = {
    "conf": {
      "triggered_by": Session.getActiveUser().getEmail(),
      "timestamp": new Date().toISOString()
    }
  };
  
  var options = {
    "method": "post",
    "contentType": "application/json",
    "headers": {
      "Authorization": "Bearer " + getServiceToken_()
    },
    "payload": JSON.stringify(payload),
    "muteHttpExceptions": true
  };
  
  try {
    var httpResponse = UrlFetchApp.fetch(webhookUrl, options);
    var statusCode = httpResponse.getResponseCode();
    
    if (statusCode === 200 || statusCode === 201) {
      ui.alert(
        'Sync Triggered Successfully!',
        'Data ingestion job has started.\nPlease allow ~2-3 minutes for the Data Warehouse to update before running BI queries.',
        ui.ButtonSet.OK
      );
    } else {
      ui.alert('Sync Warning (HTTP ' + statusCode + '): ' + httpResponse.getContentText());
    }
  } catch (err) {
    ui.alert('Error connecting to orchestrator: ' + err.toString());
  }
}

function getServiceToken_() {
  // In production, retrieve credentials safely from Script Properties
  var props = PropertiesService.getScriptProperties();
  return props.getProperty('ORCHESTRATOR_API_TOKEN') || 'mock_bearer_token';
}
