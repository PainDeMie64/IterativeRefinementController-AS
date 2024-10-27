const string NAME = "Iterative Refinement Controller";
const string ID = "iterativerefinement";

PluginInfo@ GetPluginInfo()
{
    PluginInfo info;
    info.Author = "Skycrafter & SaiMoen";
    info.Name = ID;
    info.Description = NAME;
    info.Version = "v0.0.1";
    return info;
}

bool IsOtherController()
{
    return ID != GetVariableString("controller");
}

void Main()
{
    Settings::RegisterSettings();

    IRRegisterBruteforceEvaluation("simplefinish", "Simple Finish Time", OnEvaluate, RenderEvalSettings);

    RegisterValidationHandler(ID, NAME, Settings::RenderSettings);
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    if (IsOtherController())
        return;
    simManager.RemoveStateValidation();
    preventSimulationFinish=true;
    ignoreEnd=false;
    bfInfo=IRBFEvaluationInfo();
    Eval::Initialize(simManager);
    print();
    print(TITLE + ", Mode: " + Eval::GetCurrentModeName());
    print();
    Eval::modeOnSimulationBegin(simManager);
}
enum IRBFPhase {
    Initial = 0, 
    Search = 1
}
class IRBFEvaluationInfo {
    IRBFEvaluationInfo() {
        phase = IRBFPhase::Initial;
        iterations = 0;
    }

    IRBFEvaluationInfo& opAssign(const IRBFEvaluationInfo&in other);
    
    IRBFPhase phase;
    uint iterations;
}
class IRBFEvaluationResponse {

    IRBFEvaluationResponse() {
        decision = IRBFEvaluationDecision::DoNothing;
        resultFileStartContent = "";
    }

    IRBFEvaluationResponse& opAssign(const IRBFEvaluationResponse&in other);

    IRBFEvaluationDecision decision;
    string resultFileStartContent;
}

enum IRBFEvaluationDecision {
    DoNothing = 1, 
    Accept = 2, 
    Reject = 3, 
    Stop = 4
}

bool preventSimulationFinish = false;
IRBFEvaluationInfo bfInfo;
SimulationStateFile@ startState;

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
    IRBFEvaluationResponse@ result = Eval::modeOnEvaluate(simManager, bfInfo);
    
    if (userCancelled||result.decision==IRBFEvaluationDecision::Stop) {
        Eval::SaveResult(simManager);
        Eval::Finish(simManager);
        return;
    }

    if(startState is null) {
        @startState = simManager.SaveState();
    }

    int raceTime = simManager.RaceTime;
    if(IRBFEvaluationInfo.phase==IRBFPhase::Initial && raceTime>=simManager.EventsDuration) 
    {
        IRBFEvaluationInfo.phase = IRBFPhase::Search;
        simManager.RewindToState(startState);
    }else if(IRBFEvaluationInfo.phase==IRBFPhase::Search) {
        switch(result.decision) {
            case IRBFEvaluationDecision::Accept:
                Eval::SaveResult(simManager);
                IRBFEvaluationInfo.phase=IRBFPhase::Initial;
            case IRBFEvaluationDecision::Reject:
                simManager.RewindToState(startState);
                IRBFEvaluationInfo.iterations++;
                break;
            default:
                break;
        }
    }
}

void OnCheckpointCountChanged(SimulationManager@ simManager, int, int)
{
    if (preventSimulationFinish)
        simManager.PreventSimulationFinish();
}

bool ignoreEnd = true;

void OnSimulationEnd(SimulationManager@ simManager, SimulationResult)
{
    if (ignoreEnd)
        return;

    preventSimulationFinish = false;
    ignoreEnd = true;
    Eval::modeOnEnd(simManager);
    Eval::Reset();
}


/*============================================
=                 Placeholder                =    
============================================*/

void RenderEvalSettings()
{
    // Render the evaluation settings.
}

int bestTime = -1;
BFEvaluationResponse@ OnEvaluate(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int raceTime = simManager.RaceTime;

    auto resp = BFEvaluationResponse();
    if (info.Phase == BFPhase::Initial) {
        if (simManager.PlayerInfo.RaceFinished) {
            print("Base run: " + Time::Format(raceTime));
            bestTime = raceTime;
            resp.Decision = BFEvaluationDecision::Accept;
        }
    } else if (simManager.PlayerInfo.RaceFinished) {
        if (raceTime < bestTime) {
            resp.Decision = BFEvaluationDecision::Accept;
            print("New time: " + Time::Format(raceTime));
            resp.ResultFileStartContent = "# Found better simple finish time: " + Time::Format(raceTime);
        }
    }

    return resp;
}