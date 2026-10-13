-- Existing QA workspace only. Never run with a customer credential.
local config=require('maip.config')
local client=require('maip.client')
config.setup({api_url='https://api.truthlocks.com/v1',api_key='',bearer_token=vim.env.TRUTHLOCKS_QA_TOKEN,max_retries=0})
local function call(method,path,body)
 local done,result,failure=false,nil,nil
 client.request(method,path,{body=body,on_success=function(data) result=data;done=true end,on_error=function(err) failure=err;done=true end})
 assert(vim.wait(35000,function() return done end,20),'request timeout')
 assert(not failure,failure)
 return result
end
local checks={}
local ok,err=pcall(function()
 local receipt=call('GET','/agent-receipts/'..vim.uri_encode('maip-receipt:01m4nx75rxvg56e890anryj6wn'))
 assert(type(receipt.agent_id)=='string','existing receipt has no agent')
 checks[#checks+1]='existing receipt'
 local agent=call('GET','/agents/'..vim.uri_encode(receipt.agent_id))
 assert(agent.agent_id==receipt.agent_id,'wrong identity')
 checks[#checks+1]='agent retrieval'
 local trust=call('GET','/agents/'..vim.uri_encode(receipt.agent_id)..'/trust-score')
 assert(type(trust.trust_score)=='number','missing trust score')
 checks[#checks+1]='trust score'
 local label='Truthlocks Neovim QA '..os.date('!%Y%m%dT%H%M%SZ')
 local created=call('POST','/agent-receipts',{agent_id=receipt.agent_id,receipt_type='action',action=label,metadata={kind='qa_neovim',artifact_hash=vim.fn.sha256(label),purpose='Clearly labelled synthetic release acceptance'}})
 assert(type(created.receipt_id)=='string','mint missing receipt_id')
 local verdict=call('GET','/agent-receipts/verify/'..vim.uri_encode(created.receipt_id))
 assert(verdict.valid==true and verdict.signature_verified==true and verdict.verdict=='VALID','minted signature not verified')
 checks[#checks+1]='labelled synthetic mint and cryptographic verification'
 local listed=call('GET','/agent-receipts/filter?q='..vim.uri_encode(label))
 local found=false
 for _,r in ipairs(listed.data or listed.receipts or listed.items or {}) do if r.receipt_id==created.receipt_id then found=true end end
 assert(found,'minted receipt missing from filter')
 checks[#checks+1]='filtered listing'
 print(vim.json.encode({passed=true,checks=checks,syntheticReceiptId=created.receipt_id,interactiveAcceptance=false}))
end)
local cleanup=pcall(function() call('DELETE','/sessions/current') end)
vim.env.TRUTHLOCKS_QA_TOKEN=nil
if not ok then print('QA failure: '..tostring(err));vim.cmd('cquit 1') end
assert(cleanup,'session cleanup failed')
vim.cmd('qa!')
