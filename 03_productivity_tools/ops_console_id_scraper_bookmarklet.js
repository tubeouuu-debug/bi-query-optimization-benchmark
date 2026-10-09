/**
 * Tool: 1-Click Batch Table ID Extractor (Browser Bookmarklet)
 * Author: Serena Nguyen
 * Description: Extracts batch entity IDs directly from web table rows in operational portals,
 *              cleans and formats them into a comma-separated string, and copies directly
 *              to the system clipboard for instant pasting into BI/Metabase query filters.
 * 
 * Setup Instructions:
 * 1. Open Google Chrome (or any Chromium browser). Press Ctrl + Shift + B (or Cmd + Shift + B on Mac).
 * 2. Right-click on the Bookmark Bar -> Click "Add Page..."
 * 3. Set Name: "⚡ Copy Batch IDs"
 * 4. Paste the minified code below into the URL field. Click "Save".
 */

// --- Unminified Source Code ---
(function() {
    let ids = [];
    let rows = document.querySelectorAll('table tbody tr');
    
    rows.forEach(row => {
        let firstCell = row.querySelector('td');
        if (firstCell) {
            let id = firstCell.innerText.trim();
            // Ensure ID is numeric and non-empty
            if (id && !isNaN(id)) {
                ids.push(id);
            }
        }
    });

    if (ids.length > 0) {
        let formattedIDs = ids.join(', ');
        navigator.clipboard.writeText(formattedIDs).then(() => {
            alert('✅ Successfully copied ' + ids.length + ' IDs to clipboard!\nReady to paste into BI query parameters.');
        }).catch(err => {
            alert('❌ Failed to copy to clipboard: ' + err);
        });
    } else {
        alert('⚠️ No valid IDs found in the current table.');
    }
})();

// --- Minified Bookmarklet URL (Paste this into Bookmark URL field) ---
// javascript:(function(){let ids=[];let rows=document.querySelectorAll('table tbody tr');rows.forEach(row=>{let firstCell=row.querySelector('td');if(firstCell){let id=firstCell.innerText.trim();if(id&&!isNaN(id))ids.push(id);}});if(ids.length>0){navigator.clipboard.writeText(ids.join(', ')).then(()=>alert('Successfully copied '+ids.length+' IDs! Ready to paste into BI query.'));}else{alert('No IDs found in table!');}})();
