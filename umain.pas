unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, FileUtil, fpjson, jsonparser, uFigure, uErrorChart;

type
  TQuestion = record
    ID: string;
    QuestionText: string;
    Choices: array[0..3] of string;
    CorrectIndex: Integer; // 0=A, 1=B, 2=C, 3=D, into Choices
    Sub: string;           // subelement code, e.g. 'T5'; '' if the pool has none
    Explanation: string;   // optional "why" text, shown on demand
    ChoiceNotes: array[0..3] of string; // optional one-liner per choice (same
                                         // order as Choices) saying why it's
                                         // right or wrong; '' if none for that choice
    Background: string;    // optional topic context (terms, procedures), shown under the explanation
    ExplainImage: string;  // optional diagram for the explanation (images/explain/...), '' if none
    Figure: string;        // optional diagram filename (e.g. 'e9-3.png'), '' if none
  end;

  // What happened at one position of the current run, so Back can show it
  // again and the run can be resumed after a restart of the program.
  TStep = record
    Shuffled: Boolean;            // choice order below has been fixed
    Order: array[0..3] of Integer; // display slot -> original choice index
    Chosen: Integer;              // display slot the user picked, -1 = not answered
  end;

  // One selectable question pool/exam that can be fed into the app. Pools
  // are discovered at startup by checking which of these files exist next
  // to the program - any pool whose file is missing is simply left out of
  // the "Exam:" dropdown, so the app still runs with just the ones present.
  TPoolDef = record
    DisplayName: string; // shown in the "Exam:" dropdown and the title bar
    FileName: string;    // e.g. 'questions.json'
    ExamPass: Integer;   // number correct needed to pass the real exam
  end;

  // Which of the three question-answering modes is active. Retest and
  // Mock Exam both temporarily swap out the main run (saving it first, via
  // the existing SaveProgress/LoadProgress machinery) and restore it on exit.
  TRunMode = (rmNormal, rmRetest, rmMock);

  { TForm1 }

  TForm1 = class(TForm)
    btnBack: TButton;
    btnErrorAnalysis: TButton;
    btnMock: TButton;
    btnResetErrorHistory: TButton;
    btnNext: TButton;
    btnRestart: TButton;
    btnRetest: TButton;
    btnWhy: TButton;
    cmbCategory: TComboBox;
    cmbPool: TComboBox;
    lblCategory: TLabel;
    lblExplanation: TLabel;
    lblPct: TLabel;
    lblpct_unit: TLabel;
    lblFooter: TLabel;
    lblPool: TLabel;
    lblProgress: TLabel;
    lblQID: TLabel;
    lblQuestion: TLabel;
    lblResult: TLabel;
    lblScore: TLabel;
    rgChoices: TRadioGroup;
    procedure btnBackClick(Sender: TObject);
    procedure btnErrorAnalysisClick(Sender: TObject);
    procedure btnMockClick(Sender: TObject);
    procedure btnResetErrorHistoryClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnRestartClick(Sender: TObject);
    procedure btnRetestClick(Sender: TObject);
    procedure btnWhyClick(Sender: TObject);
    procedure cmbPoolChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure rgChoicesClick(Sender: TObject);
    procedure cmbCategoryChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FQuestions: array of TQuestion;
    FFiltered: array of Integer;   // indices into FQuestions, filtered by category, shuffled
    FPos: Integer;                 // position within FFiltered
    FAsked, FCorrect: Integer;
    PercVal: Double;
    FDisplayMap: array[0..3] of Integer; // display slot -> original choice index
    FSteps: array of TStep;        // one per position in FFiltered
    FCurCat: Integer;              // category index the current run belongs to
    FAnswered: Boolean;
    FCatPrefixes: array of string;
    FImagesDir: string;
    FFigureForm: TFormFigure; // lazily-created non-modal popup for diagrams
    FExplainForm: TFormFigure; // second popup for the explanation diagram (Why?)
    FPools: array of TPoolDef;     // exams discovered next to the program
    FCurPoolIdx: Integer;          // index into FPools of the loaded pool
    FRunMode: TRunMode;
    FWrongIDs: TStringList;        // IDs missed on the most recent attempt, this pool
    // Error Analysis counts, all indexed like FQuestions:
    FHistoryAsked, FHistoryErrors: array of Integer; // every answer ever, this pool (saved)
    FRoundAsked, FRoundErrors: array of Integer;     // current main study run only
    procedure LoadQuestions(const FileName: string);
    function ReadFileUTF8(const FileName: string): string;
    function ResolveDataFile(const BaseName: string): string;
    procedure LoadPool(AIndex: Integer; AResume: Boolean);
    function HasWhyContent(const q: TQuestion): Boolean;
    function SubelementTitle(const Prefix: string): string;
    function ExamClassName: string;
    function GroupKeyOf(const AID: string): string;
    function GroupCount: Integer;
    function CurrentMaxMisses: Integer;
    procedure BuildCategoryList;
    procedure ApplyFilterAndReset;
    procedure ShowCurrentQuestion;
    procedure ShowFinishedState;
    procedure UpdateScoreLabel;
    procedure ShowFigurePopup(const FigureFile, FigureCaption: string);
    procedure CloseFigurePopup;
    procedure ShowExplainPopup(const ImageFile, ACaption: string);
    procedure CloseExplainPopup;
    procedure PlacePopup(F: TForm; Row: Integer);
    function ShowAnswerResult(const q: TQuestion; Slot: Integer): Boolean;
    function FindQuestion(const AID: string): Integer;
    function ProgressFileName: string;
    procedure SaveProgress;
    function LoadProgress: Boolean;
    function ConfirmDiscardProgress: Boolean;
    function WrongFileName: string;
    procedure LoadWrongList;
    procedure SaveWrongList;
    procedure MarkWrong(const AID: string);
    procedure MarkCorrect(const AID: string);
    procedure UpdateRunModeButtons;
    procedure StartRetestRun;
    procedure BuildMockExam;
    procedure StartMockRun;
    function AnalysisKeyOf(const q: TQuestion): string;
    function ErrorHistoryFileName: string;
    procedure LoadErrorHistory;
    procedure SaveErrorHistory;
    procedure RecordHistoricalAnswer(AIndex: Integer; IsWrong: Boolean);
    procedure RebuildRoundCounts;
    procedure MigrateOldDataDir;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  // Exams that the app knows how to offer, in the order they appear in the
  // "Exam:" dropdown. Only the ones whose file is actually found next to
  // the program are shown - so the app works whether you have just the
  // Amateur Extra pool, just the GROL pools, or all three. Drop a new
  // questions.json-shaped file in next to the program (see README) and add
  // a line here to offer it too.
  PoolCandidateCount = 5;
  PoolCandidateFile: array[0..PoolCandidateCount - 1] of string =
    ('questions.json', 'grol_element1.json', 'grol_element3.json',
     'grol_element7.json', 'grol_element8.json');
  PoolCandidateName: array[0..PoolCandidateCount - 1] of string =
    ('Amateur Extra (Element 4)',
     'GROL Element 1 - Radio Law & Operating Practice',
     'GROL Element 3 - General Radiotelephone',
     'Element 7 - GMDSS Radio Operator',
     'Element 8 - Ship RADAR Techniques');
  // Questions correct needed to pass the real exam: 37/50 for Extra,
  // 18/24 for GROL Element 1, 75/100 for GROL Element 3, 75/100 for
  // Element 7 (GMDSS), 38/50 for Element 8 (the RADAR endorsement).
  PoolCandidatePass: array[0..PoolCandidateCount - 1] of Integer = (37, 18, 75, 75, 38);

{ TForm1 }

function TForm1.ReadFileUTF8(const FileName: string): string;
var
  fs: TFileStream;
  Bytes: TBytes;
begin
  fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Bytes, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(Bytes[0], fs.Size);
  finally
    fs.Free;
  end;
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function TForm1.ResolveDataFile(const BaseName: string): string;
var
  p: string;
begin
  // Looked for next to the executable, one folder up, or in the current
  // directory - same tolerant search for every pool's file.
  p := ExtractFilePath(ParamStr(0)) + BaseName;
  if FileExists(p) then Exit(p);
  p := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + BaseName;
  if FileExists(p) then Exit(p);
  if FileExists(BaseName) then Exit(BaseName);
  Result := '';
end;

procedure TForm1.LoadQuestions(const FileName: string);
var
  JSONData: TJSONData;
  JSONArr: TJSONArray;
  JSONObj: TJSONObject;
  ChoicesArr: TJSONArray;
  NotesData: TJSONData;
  NotesArr: TJSONArray;
  i, j: Integer;
  JsonText: string;
begin
  JsonText := ReadFileUTF8(FileName);
  JSONData := GetJSON(JsonText);
  try
    if not (JSONData is TJSONArray) then
      raise Exception.Create(ExtractFileName(FileName) + ' does not contain a JSON array at the top level.');
    JSONArr := TJSONArray(JSONData);
    SetLength(FQuestions, JSONArr.Count);
    for i := 0 to JSONArr.Count - 1 do
    begin
      JSONObj := TJSONObject(JSONArr[i]);
      FQuestions[i].ID := JSONObj.Get('id', '');
      FQuestions[i].QuestionText := JSONObj.Get('question', '');
      FQuestions[i].CorrectIndex := JSONObj.Get('correct', 0);
      FQuestions[i].Explanation := JSONObj.Get('explanation', '');
      FQuestions[i].Background := JSONObj.Get('background', '');
      FQuestions[i].ExplainImage := JSONObj.Get('explanation_image', '');
      FQuestions[i].Figure := JSONObj.Get('figure', '');
      // Subelement filtering only makes sense for the lettered pools
      // (T0-T9 / G0-G9 / E0-E9). The GROL pools' IDs start with a digit
      // ("1-7B4") and have no equivalent named grouping, so they get no
      // category breakdown - just "All subelements".
      if (Length(FQuestions[i].ID) > 0) and (FQuestions[i].ID[1] in ['A'..'Z', 'a'..'z']) then
        FQuestions[i].Sub := Copy(FQuestions[i].ID, 1, 2)
      else
        FQuestions[i].Sub := '';
      ChoicesArr := JSONObj.Arrays['choices'];
      for j := 0 to 3 do
      begin
        if j < ChoicesArr.Count then
          FQuestions[i].Choices[j] := ChoicesArr.Strings[j]
        else
          FQuestions[i].Choices[j] := '';
      end;

      // Optional per-choice "why" notes - same order as "choices". Not
      // every pool has these yet, so a missing or malformed field just
      // leaves all four blank rather than failing to load.
      NotesData := JSONObj.Find('choice_notes');
      if (NotesData <> nil) and (NotesData is TJSONArray) then
      begin
        NotesArr := TJSONArray(NotesData);
        for j := 0 to 3 do
          if j < NotesArr.Count then
            FQuestions[i].ChoiceNotes[j] := NotesArr.Strings[j]
          else
            FQuestions[i].ChoiceNotes[j] := '';
      end
      else
        for j := 0 to 3 do
          FQuestions[i].ChoiceNotes[j] := '';
    end;
  finally
    JSONData.Free;
  end;
end;

function TForm1.HasWhyContent(const q: TQuestion): Boolean;
var
  i: Integer;
begin
  Result := (Trim(q.Explanation) <> '') or (Trim(q.Background) <> '');
  if not Result then
    for i := 0 to 3 do
      if Trim(q.ChoiceNotes[i]) <> '' then
      begin
        Result := True;
        Break;
      end;
end;

function TForm1.SubelementTitle(const Prefix: string): string;
const
  // Human-readable subelement names, covering the Technician (T),
  // General (G) and Amateur Extra (E) syllabi. If a future or unknown
  // pool uses a prefix not listed here, we just fall back to a generic
  // label rather than failing - the filter still works either way.
  Known: array[0..66, 0..1] of string = (
    ('T0', 'Safety'),
    ('T1', 'Commission''s Rules'),
    ('T2', 'Operating Procedures'),
    ('T3', 'Radio Wave Propagation'),
    ('T4', 'Amateur Radio Practices and Station Setup'),
    ('T5', 'Electrical Principles'),
    ('T6', 'Electrical Components'),
    ('T7', 'Station Equipment'),
    ('T8', 'Modulation Modes'),
    ('T9', 'Antennas and Feed Lines'),
    ('G0', 'Electrical and RF Safety'),
    ('G1', 'Commission''s Rules'),
    ('G2', 'Operating Procedures'),
    ('G3', 'Radio Wave Propagation'),
    ('G4', 'Amateur Radio Practices'),
    ('G5', 'Electrical Principles'),
    ('G6', 'Circuit Components'),
    ('G7', 'Practical Circuits'),
    ('G8', 'Signals and Emissions'),
    ('G9', 'Antennas and Feed Lines'),
    ('E0', 'Electrical and RF Safety'),
    ('E1', 'Commission''s Rules'),
    ('E2', 'Operating Procedures'),
    ('E3', 'Radio Wave Propagation'),
    ('E4', 'Amateur Radio Practices'),
    ('E5', 'Electrical Principles'),
    ('E6', 'Circuit Components'),
    ('E7', 'Practical Circuits'),
    ('E8', 'Signals and Emissions'),
    ('E9', 'Antennas and Feed Lines'),
    // GROL pools: '<element>-<subelement letter>', the official FCC
    // subelements (used by Error Analysis; see AnalysisKeyOf).
    ('1-A', 'Rules & Regulations'),
    ('1-B', 'Communications Procedures'),
    ('1-C', 'Equipment Operations'),
    ('1-D', 'Other Equipment'),
    ('3-A', 'Principles'),
    ('3-B', 'Electrical Math'),
    ('3-C', 'Components'),
    ('3-D', 'Circuits'),
    ('3-E', 'Digital Logic'),
    ('3-F', 'Receivers'),
    ('3-G', 'Transmitters'),
    ('3-H', 'Modulation'),
    ('3-I', 'Power Sources'),
    ('3-J', 'Antennas'),
    ('3-K', 'Aircraft'),
    ('3-L', 'Installation, Maintenance & Repair'),
    ('3-M', 'Communications Technology'),
    ('3-N', 'Marine'),
    ('3-O', 'RADAR'),
    ('3-P', 'Satellite'),
    ('3-Q', 'Safety'),
    ('7-A', 'General Information & System Overview'),
    ('7-B', 'Principles of Communications'),
    ('7-C', 'FCC Rules & Regulations'),
    ('7-D', 'DSC & Alpha-Numeric ID'),
    ('7-E', 'Distress, Urgency & Safety Communications'),
    ('7-F', 'Survival Craft Equipment & SAR'),
    ('7-G', 'VHF-DSC Equipment & Communications'),
    ('7-H', 'Maritime Safety Information (MSI)'),
    ('7-I', 'Inmarsat Equipment & Communications'),
    ('7-J', 'MF-HF Equipment & Communications'),
    ('8-A', 'RADAR Principles'),
    ('8-B', 'Transmitting Systems'),
    ('8-C', 'Receiving Systems'),
    ('8-D', 'Display & Control Systems'),
    ('8-E', 'Antenna Systems'),
    ('8-F', 'Installation, Maintenance & Repair')
  );
var
  i: Integer;
begin
  for i := 0 to High(Known) do
    if Known[i, 0] = Prefix then
      Exit(Known[i, 1]);
  Result := 'Miscellaneous';
end;

function TForm1.ExamClassName: string;
begin
  if (FCurPoolIdx >= 0) and (FCurPoolIdx <= High(FPools)) then
    Exit(FPools[FCurPoolIdx].DisplayName);
  Result := 'Amateur Radio License';
end;

// Strips the trailing digits off a question ID to get the "group" it
// belongs to, e.g. 'E5A01' -> 'E5A', '1-7B4' -> '1-7B', '3-100D6' -> '3-100D'.
// Every pool this app loads (Technician/General/Extra and both GROL pools)
// is organised the same way: the real exam draws exactly one question per
// group, so this one function is all that's needed to build an
// official-length, official-composition mock exam for any of them.
function TForm1.GroupKeyOf(const AID: string): string;
var
  i: Integer;
begin
  Result := AID;
  i := Length(Result);
  while (i > 0) and (Result[i] in ['0'..'9']) do
    Dec(i);
  Result := Copy(Result, 1, i);
end;

function TForm1.GroupCount: Integer;
var
  i: Integer;
  keys: TStringList;
begin
  keys := TStringList.Create;
  try
    keys.Sorted := True;
    keys.Duplicates := dupIgnore;
    for i := 0 to High(FQuestions) do
      keys.Add(GroupKeyOf(FQuestions[i].ID));
    Result := keys.Count;
  finally
    keys.Free;
  end;
end;

function TForm1.CurrentMaxMisses: Integer;
begin
  // The most questions you can miss and still pass the real exam for
  // whichever pool is loaded (13 of 50 for Extra, 6 of 24 for GROL
  // Element 1, 25 of 100 for GROL Element 3, 25 of 100 for Element 7,
  // 12 of 50 for Element 8).
  // The running percentage turns red once you've missed more than this.
  if (FCurPoolIdx >= 0) and (FCurPoolIdx <= High(FPools)) then
    Result := GroupCount - FPools[FCurPoolIdx].ExamPass
  else
    Result := 13;
end;

procedure TForm1.BuildCategoryList;
var
  i: Integer;
  prefixes: TStringList;
begin
  // Derive the list of subelements straight from whatever pool was
  // loaded, rather than assuming it's the Technician pool. This is what
  // lets a different pool be dropped in as just a new file, with no code
  // changes needed. Questions with no subelement (Sub = '', e.g. the GROL
  // pools) are left out - they're covered by "All subelements" already.
  prefixes := TStringList.Create;
  try
    prefixes.Sorted := True;
    prefixes.Duplicates := dupIgnore;
    for i := 0 to High(FQuestions) do
      if FQuestions[i].Sub <> '' then
        prefixes.Add(FQuestions[i].Sub);

    SetLength(FCatPrefixes, prefixes.Count + 1);
    FCatPrefixes[0] := '';

    cmbCategory.Items.BeginUpdate;
    try
      cmbCategory.Items.Clear;
      cmbCategory.Items.Add('All subelements');
      for i := 0 to prefixes.Count - 1 do
      begin
        FCatPrefixes[i + 1] := prefixes[i];
        cmbCategory.Items.Add(prefixes[i] + ' - ' + SubelementTitle(prefixes[i]));
      end;
    finally
      cmbCategory.Items.EndUpdate;
    end;
  finally
    prefixes.Free;
  end;
  cmbCategory.ItemIndex := 0;
end;

procedure TForm1.ApplyFilterAndReset;
var
  i, n, k, r: Integer;
  prefix: string;
  tmp: Integer;
begin
  if (cmbCategory.ItemIndex < 0) or (cmbCategory.ItemIndex > High(FCatPrefixes)) then
    prefix := ''
  else
    prefix := FCatPrefixes[cmbCategory.ItemIndex];

  SetLength(FFiltered, 0);
  n := 0;
  SetLength(FFiltered, Length(FQuestions));
  for i := 0 to High(FQuestions) do
  begin
    if (prefix = '') or (FQuestions[i].Sub = prefix) then
    begin
      FFiltered[n] := i;
      Inc(n);
    end;
  end;
  SetLength(FFiltered, n);

  // Fisher-Yates shuffle
  for k := High(FFiltered) downto 1 do
  begin
    r := Random(k + 1);
    tmp := FFiltered[k];
    FFiltered[k] := FFiltered[r];
    FFiltered[r] := tmp;
  end;

  SetLength(FSteps, n);
  for i := 0 to n - 1 do
  begin
    FSteps[i].Shuffled := False;
    FSteps[i].Chosen := -1;
  end;
  FCurCat := cmbCategory.ItemIndex;
  RebuildRoundCounts; // all steps unanswered, so this just zeroes them

  FPos := 0;
  FAsked := 0;
  FCorrect := 0;
  rgChoices.Enabled := True;
  btnNext.Enabled := False;
  btnBack.Enabled := False;
  UpdateScoreLabel;

  if Length(FFiltered) = 0 then
  begin
    lblQID.Caption := '';
    lblQuestion.Caption := 'No questions found for this category.';
    rgChoices.Items.Clear;
    rgChoices.Enabled := False;
    lblResult.Caption := '';
    lblProgress.Caption := '';
    btnWhy.Enabled := False;
    btnBack.Enabled := False;
    lblExplanation.Caption := '';
    CloseFigurePopup;
    CloseExplainPopup;
  end
  else
    ShowCurrentQuestion;
  SaveProgress;
end;

procedure TForm1.ShowCurrentQuestion;
var
  q: TQuestion;
  i, k, r, tmp: Integer;
  Letters: array[0..3] of Char;
begin
  Letters[0] := 'A'; Letters[1] := 'B'; Letters[2] := 'C'; Letters[3] := 'D';

  btnBack.Enabled := FPos > 0;

  if (FPos < 0) or (FPos >= Length(FFiltered)) then
  begin
    ShowFinishedState;
    Exit;
  end;

  // Block the click handler while the radio group is rebuilt.
  FAnswered := True;

  q := FQuestions[FFiltered[FPos]];

  lblProgress.Caption := Format('Question %d of %d', [FPos + 1, Length(FFiltered)]);
  lblQID.Caption := q.ID;
  lblQuestion.Caption := q.QuestionText;
  lblResult.Caption := '';
  lblResult.Font.Color := clWindowText;
  lblExplanation.Caption := '';

  // Shuffle the display order of the four choices so the correct answer
  // is not always in the same position. It is shuffled only once per
  // position and remembered, so going Back shows the same order.
  if not FSteps[FPos].Shuffled then
  begin
    for i := 0 to 3 do
      FSteps[FPos].Order[i] := i;
    for k := 3 downto 1 do
    begin
      r := Random(k + 1);
      tmp := FSteps[FPos].Order[k];
      FSteps[FPos].Order[k] := FSteps[FPos].Order[r];
      FSteps[FPos].Order[r] := tmp;
    end;
    FSteps[FPos].Shuffled := True;
  end;

  rgChoices.Items.BeginUpdate;
  try
    rgChoices.Items.Clear;
    for i := 0 to 3 do
    begin
      FDisplayMap[i] := FSteps[FPos].Order[i];
      // '&' marks a keyboard accelerator in LCL captions (it would show as
      // an underline, e.g. Element 7's "position & time"), so double it.
      rgChoices.Items.Add(Letters[i] + '.  ' +
        StringReplace(q.Choices[FDisplayMap[i]], '&', '&&', [rfReplaceAll]));
    end;
  finally
    rgChoices.Items.EndUpdate;
  end;

  // A handful of questions (E5C, E6A/B/C, E7B/D/G, E9B/G) refer to a
  // labeled diagram, schematic, or chart. Pop it up in its own window,
  // big enough to actually read, only when this question has one.
  CloseExplainPopup;
  if (q.Figure <> '') and FileExists(FImagesDir + q.Figure) then
    ShowFigurePopup(FImagesDir + q.Figure,
      'Figure ' + UpperCase(ChangeFileExt(q.Figure, '')))
  else
    CloseFigurePopup;

  if FSteps[FPos].Chosen >= 0 then
  begin
    // Answered before (we got here with Back, or Next after Back):
    // show the earlier answer again, read-only. The score is NOT touched.
    rgChoices.ItemIndex := FSteps[FPos].Chosen;
    ShowAnswerResult(q, FSteps[FPos].Chosen);
    rgChoices.Enabled := False;
    btnNext.Enabled := True;
    btnWhy.Enabled := HasWhyContent(q);
  end
  else
  begin
    rgChoices.ItemIndex := -1;
    rgChoices.Enabled := True;
    btnNext.Enabled := False;
    // Why? is available even before an answer is picked, not just after -
    // so it's gated purely on whether this question has any explanation
    // content, not on FAnswered.
    btnWhy.Enabled := HasWhyContent(q);
    FAnswered := False;
  end;
end;

procedure TForm1.ShowFinishedState;
var
  pct: Double;
  passed: Boolean;
  passLine: string;
begin
  lblProgress.Caption := 'Quiz complete!';
  lblQID.Caption := '';
  lblQuestion.Caption := '';
  rgChoices.Items.Clear;
  rgChoices.Enabled := False;
  btnNext.Enabled := False;
  btnWhy.Enabled := False;
  btnBack.Enabled := Length(FFiltered) > 0;
  lblExplanation.Caption := '';
  CloseFigurePopup;
  CloseExplainPopup;

  if FAsked > 0 then
    pct := (FCorrect / FAsked) * 100.0
  else
    pct := 0.0;

  lblResult.Font.Color := clNavy;
  case FRunMode of
    rmRetest:
      lblResult.Caption := Format(
        'Retest done: %d out of %d correct (%.1f%%).'#13#10 +
        'Click "Back to Study" to resume your main run.',
        [FCorrect, FAsked, pct]);
    rmMock:
      begin
        passed := FCorrect >= FPools[FCurPoolIdx].ExamPass;
        passLine := IfThen(passed, 'PASS', 'FAIL');
        if passed then
          lblResult.Font.Color := clGreen
        else
          lblResult.Font.Color := clRed;
        lblResult.Caption := Format(
          'Mock exam complete: %d of %d correct (%.1f%%) - %d needed to pass.  %s'#13#10 +
          'Click "Back to Study" to resume your main run.',
          [FCorrect, FAsked, pct, FPools[FCurPoolIdx].ExamPass, passLine]);
      end;
  else
    lblResult.Caption := Format(
      'You answered %d out of %d correctly (%.1f%%).'#13#10 +
      'Click "Restart / Reshuffle" to try again.',
      [FCorrect, FAsked, pct]);
  end;
end;

procedure TForm1.UpdateScoreLabel;
begin
  lblScore.Caption := Format('Score: %d / %d', [FCorrect, FAsked]);
  if FAsked > 0 then PercVal := (FCorrect / FAsked) * 100 else PercVal := 0;
  lblPct.Caption := Format('%.1f', [PercVal]);
  if FAsked - FCorrect > CurrentMaxMisses then
    lblPct.Font.Color := clRed
  else
    lblPct.Font.Color := clDefault;
end;

procedure TForm1.ShowFigurePopup(const FigureFile, FigureCaption: string);
begin
  // Created once, then reused (shown/hidden) for the life of the app -
  // a plain, non-modal 600x400 window so the diagram is actually
  // readable, positioned beside the main window rather than on top of it.
  if not Assigned(FFigureForm) then
  begin
    FFigureForm := TFormFigure.Create(Self);
    FFigureForm.Width := 600;
    FFigureForm.Height := 400;
    PlacePopup(FFigureForm, 0);
  end;
  FFigureForm.LoadImage(FigureFile, FigureCaption);
  FFigureForm.Show;
end;

procedure TForm1.CloseFigurePopup;
begin
  if Assigned(FFigureForm) then
    FFigureForm.Hide;
end;

procedure TForm1.PlacePopup(F: TForm; Row: Integer);
var
  L, T: Integer;
begin
  // Beside the main window if there is room, otherwise pulled back in so
  // the popup always stays on screen. Row 0 = top, row 1 = below the
  // figure popup.
  L := Self.Left + Self.Width + 16;
  if L + F.Width > Screen.WorkAreaLeft + Screen.WorkAreaWidth then
    L := Screen.WorkAreaLeft + Screen.WorkAreaWidth - F.Width - 8;
  if L < Screen.WorkAreaLeft then
    L := Screen.WorkAreaLeft;
  T := Self.Top + Row * (F.Height + 40);
  if T + F.Height + 40 > Screen.WorkAreaTop + Screen.WorkAreaHeight then
    T := Screen.WorkAreaTop + Screen.WorkAreaHeight - F.Height - 40;
  if T < Screen.WorkAreaTop then
    T := Screen.WorkAreaTop;
  F.Left := L;
  F.Top := T;
end;

procedure TForm1.ShowExplainPopup(const ImageFile, ACaption: string);
var
  Row: Integer;
begin
  // Same kind of window as the figure popup, reused for every question.
  if not Assigned(FExplainForm) then
  begin
    FExplainForm := TFormFigure.Create(Self);
    FExplainForm.Width := 600;
    FExplainForm.Height := 400;
  end;
  if not FExplainForm.Visible then
  begin
    if Assigned(FFigureForm) and FFigureForm.Visible then
      Row := 1
    else
      Row := 0;
    PlacePopup(FExplainForm, Row);
  end;
  FExplainForm.LoadImage(ImageFile, ACaption);
  FExplainForm.Show;
end;

procedure TForm1.CloseExplainPopup;
begin
  if Assigned(FExplainForm) then
    FExplainForm.Hide;
end;

function TForm1.ShowAnswerResult(const q: TQuestion; Slot: Integer): Boolean;
var
  correctLetter: Char;
  Letters: array[0..3] of Char;
  i: Integer;
begin
  // Shows right/wrong for the answer in display slot Slot; returns True if
  // it was correct. Does not change the score.
  Letters[0] := 'A'; Letters[1] := 'B'; Letters[2] := 'C'; Letters[3] := 'D';
  Result := (FDisplayMap[Slot] = q.CorrectIndex);

  correctLetter := 'A';
  for i := 0 to 3 do
    if FDisplayMap[i] = q.CorrectIndex then
      correctLetter := Letters[i];

  if Result then
  begin
    lblResult.Font.Color := clGreen;
    lblResult.Caption := 'Correct!  ' + correctLetter + '.  ' + q.Choices[q.CorrectIndex];
  end
  else
  begin
    lblResult.Font.Color := clRed;
    lblResult.Caption := 'Incorrect.  The correct answer is ' + correctLetter +
      '.  ' + q.Choices[q.CorrectIndex];
  end;
end;

procedure TForm1.rgChoicesClick(Sender: TObject);
var
  q: TQuestion;
begin
  // Fires whenever the user clicks any radio button in the group. Guard
  // against re-entry (once a question is answered the group gets
  // disabled, but a stray click could still land here), against the
  // group being rebuilt, and against a click on the group box itself.
  if FAnswered then
    Exit;

  if rgChoices.ItemIndex < 0 then
    Exit;

  q := FQuestions[FFiltered[FPos]];
  FSteps[FPos].Chosen := rgChoices.ItemIndex;

  // Only a first answer counts; Back never comes through here.
  Inc(FAsked);
  if ShowAnswerResult(q, rgChoices.ItemIndex) then
  begin
    Inc(FCorrect);
    RecordHistoricalAnswer(FFiltered[FPos], False);
    MarkCorrect(q.ID);
  end
  else
  begin
    RecordHistoricalAnswer(FFiltered[FPos], True);
    MarkWrong(q.ID);
  end;

  UpdateScoreLabel;
  rgChoices.Enabled := False;
  btnNext.Enabled := True;
  btnWhy.Enabled := HasWhyContent(q);
  FAnswered := True;
  SaveProgress;
end;

procedure TForm1.btnNextClick(Sender: TObject);
begin
  Inc(FPos);
  ShowCurrentQuestion;
  SaveProgress;
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  // Step back through the run. Answers already given are shown again
  // read-only; the score is never changed by going back.
  if FPos > Length(FFiltered) then
    FPos := Length(FFiltered);
  if FPos > 0 then
  begin
    Dec(FPos);
    ShowCurrentQuestion;
    SaveProgress;
  end;
end;

function TForm1.FindQuestion(const AID: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FQuestions) do
    if FQuestions[i].ID = AID then
      Exit(i);
  Result := -1;
end;

function TForm1.ProgressFileName: string;
begin
  // e.g. C:\Users\<you>\AppData\Local\hamquiz\progress_e.txt
  // (one file per pool - 'e', '1' or '3' - so the different exams don't clash)
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  ForceDirectories(Result);
  Result := Result + 'progress_' + LowerCase(Copy(FQuestions[0].ID, 1, 1)) + '.txt';
end;

procedure TForm1.SaveProgress;
var
  sl: TStringList;
  i, j: Integer;
  s, prefix: string;
begin
  // Retest and Mock Exam runs are never saved as "the" progress for this
  // pool - they're temporary detours. The main run was already saved
  // (by whichever button started the detour) just before FRunMode changed.
  if FRunMode <> rmNormal then
    Exit;
  if (Length(FQuestions) = 0) or (Length(FFiltered) = 0) then
    Exit;
  if (FCurCat >= 0) and (FCurCat <= High(FCatPrefixes)) then
    prefix := FCatPrefixes[FCurCat]
  else
    prefix := '';

  sl := TStringList.Create;
  try
    sl.Add('version=1');
    sl.Add('category=' + prefix);
    sl.Add('pos=' + IntToStr(FPos));
    sl.Add('asked=' + IntToStr(FAsked));
    sl.Add('correct=' + IntToStr(FCorrect));
    sl.Add('count=' + IntToStr(Length(FFiltered)));
    // q<n>=<ID>,<order0..3 or -1>,<chosen slot or -1>
    for i := 0 to High(FFiltered) do
    begin
      s := FQuestions[FFiltered[i]].ID;
      for j := 0 to 3 do
        if FSteps[i].Shuffled then
          s := s + ',' + IntToStr(FSteps[i].Order[j])
        else
          s := s + ',-1';
      s := s + ',' + IntToStr(FSteps[i].Chosen);
      sl.Add('q' + IntToStr(i) + '=' + s);
    end;
    try
      sl.SaveToFile(ProgressFileName);
    except
      // Not fatal: the quiz still works, the run just won't be resumable.
    end;
  finally
    sl.Free;
  end;
end;

function TForm1.LoadProgress: Boolean;
var
  sl, parts: TStringList;
  fn, prefix: string;
  i, j, n, idx, cat: Integer;
  used: array[0..3] of Boolean;
begin
  Result := False;
  if Length(FQuestions) = 0 then
    Exit;
  fn := ProgressFileName;
  if not FileExists(fn) then
    Exit;

  sl := TStringList.Create;
  parts := TStringList.Create;
  try
    try
      sl.LoadFromFile(fn);
      if sl.Values['version'] <> '1' then
        Exit;

      prefix := sl.Values['category'];
      cat := -1;
      for i := 0 to High(FCatPrefixes) do
        if FCatPrefixes[i] = prefix then
        begin
          cat := i;
          Break;
        end;
      if cat < 0 then
        Exit;

      n := StrToIntDef(sl.Values['count'], 0);
      if n <= 0 then
        Exit;
      SetLength(FFiltered, n);
      SetLength(FSteps, n);
      parts.Delimiter := ',';
      parts.StrictDelimiter := True;
      for i := 0 to n - 1 do
      begin
        parts.DelimitedText := sl.Values['q' + IntToStr(i)];
        if parts.Count <> 6 then
          Exit;
        idx := FindQuestion(parts[0]);
        if idx < 0 then
          Exit;   // question pool changed: start a fresh run instead
        FFiltered[i] := idx;

        // order must be a permutation of 0..3, otherwise reshuffle later
        FSteps[i].Shuffled := True;
        for j := 0 to 3 do
          used[j] := False;
        for j := 0 to 3 do
        begin
          FSteps[i].Order[j] := StrToIntDef(parts[1 + j], -1);
          if (FSteps[i].Order[j] < 0) or (FSteps[i].Order[j] > 3) or used[FSteps[i].Order[j]] then
            FSteps[i].Shuffled := False
          else
            used[FSteps[i].Order[j]] := True;
        end;
        FSteps[i].Chosen := StrToIntDef(parts[5], -1);
        if (not FSteps[i].Shuffled) or (FSteps[i].Chosen < 0) or (FSteps[i].Chosen > 3) then
          FSteps[i].Chosen := -1;
      end;

      cmbCategory.ItemIndex := cat;
      FCurCat := cat;
      FPos := StrToIntDef(sl.Values['pos'], 0);
      if FPos < 0 then FPos := 0;
      if FPos > n then FPos := n;
      FAsked := StrToIntDef(sl.Values['asked'], 0);
      FCorrect := StrToIntDef(sl.Values['correct'], 0);
      RebuildRoundCounts;
      Result := True;
    except
      Result := False;
    end;
  finally
    parts.Free;
    sl.Free;
    if not Result then
    begin
      SetLength(FFiltered, 0);
      SetLength(FSteps, 0);
    end;
  end;
end;

function TForm1.ConfirmDiscardProgress: Boolean;
begin
  // Starting over throws away the saved run, so ask first if there is one.
  Result := (FAsked = 0) or
    (MessageDlg('Start over?',
      Format('This starts a new shuffled run and discards your progress ' +
        '(%d answered, at question %d of %d).',
        [FAsked, Min(FPos + 1, Length(FFiltered)), Length(FFiltered)]),
      mtConfirmation, [mbYes, mbNo], 0) = mrYes);
end;

function TForm1.WrongFileName: string;
begin
  // e.g. C:\Users\<you>\AppData\Local\hamquiz\wrong_e.txt - one per pool,
  // a flat list of question IDs most recently answered incorrectly.
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  ForceDirectories(Result);
  Result := Result + 'wrong_' + LowerCase(Copy(FQuestions[0].ID, 1, 1)) + '.txt';
end;

procedure TForm1.LoadWrongList;
var
  sl: TStringList;
  i: Integer;
  fn, id: string;
begin
  FWrongIDs.Clear;
  if Length(FQuestions) = 0 then
    Exit;
  fn := WrongFileName;
  if not FileExists(fn) then
    Exit;
  sl := TStringList.Create;
  try
    try
      sl.LoadFromFile(fn);
      for i := 0 to sl.Count - 1 do
      begin
        id := Trim(sl[i]);
        // Drop any ID the currently-loaded pool no longer has (e.g. the
        // pool file was edited), rather than failing to load.
        if (id <> '') and (FindQuestion(id) >= 0) then
          FWrongIDs.Add(id);
      end;
    except
      // Corrupt or unreadable file: just start with an empty list.
    end;
  finally
    sl.Free;
  end;
end;

procedure TForm1.SaveWrongList;
begin
  if Length(FQuestions) = 0 then
    Exit;
  try
    FWrongIDs.SaveToFile(WrongFileName);
  except
    // Not fatal: Retest just won't remember across restarts.
  end;
end;

procedure TForm1.MarkWrong(const AID: string);
begin
  if FWrongIDs.IndexOf(AID) < 0 then
  begin
    FWrongIDs.Add(AID);
    SaveWrongList;
  end;
  UpdateRunModeButtons;
end;

procedure TForm1.MarkCorrect(const AID: string);
var
  idx: Integer;
begin
  idx := FWrongIDs.IndexOf(AID);
  if idx >= 0 then
  begin
    FWrongIDs.Delete(idx);
    SaveWrongList;
  end;
  UpdateRunModeButtons;
end;

procedure TForm1.UpdateRunModeButtons;
begin
  cmbPool.Enabled := (FRunMode = rmNormal);
  cmbCategory.Enabled := (FRunMode = rmNormal);
  btnRestart.Enabled := (FRunMode = rmNormal);

  btnRetest.Enabled := (FRunMode = rmRetest) or
    ((FRunMode = rmNormal) and (FWrongIDs.Count > 0));
  if FRunMode = rmRetest then
    btnRetest.Caption := 'Back to Study'
  else if FWrongIDs.Count > 0 then
    btnRetest.Caption := Format('Retest Wrong Answers (%d)', [FWrongIDs.Count])
  else
    btnRetest.Caption := 'Retest Wrong Answers';

  btnMock.Enabled := (FRunMode = rmMock) or (FRunMode = rmNormal);
  if FRunMode = rmMock then
    btnMock.Caption := 'Back to Study'
  else
    btnMock.Caption := 'Mock Exam';
end;

procedure TForm1.StartRetestRun;
var
  i, idx, k, r, tmp: Integer;
begin
  FRunMode := rmRetest;

  SetLength(FFiltered, FWrongIDs.Count);
  k := 0;
  for i := 0 to FWrongIDs.Count - 1 do
  begin
    idx := FindQuestion(FWrongIDs[i]);
    if idx >= 0 then
    begin
      FFiltered[k] := idx;
      Inc(k);
    end;
  end;
  SetLength(FFiltered, k);

  for i := High(FFiltered) downto 1 do
  begin
    r := Random(i + 1);
    tmp := FFiltered[i];
    FFiltered[i] := FFiltered[r];
    FFiltered[r] := tmp;
  end;

  SetLength(FSteps, Length(FFiltered));
  for i := 0 to High(FSteps) do
  begin
    FSteps[i].Shuffled := False;
    FSteps[i].Chosen := -1;
  end;

  FPos := 0;
  FAsked := 0;
  FCorrect := 0;
  rgChoices.Enabled := True;
  btnNext.Enabled := False;
  btnBack.Enabled := False;
  UpdateScoreLabel;
  UpdateRunModeButtons;
  lblFooter.Caption := Format('Retest mode: %d previously-missed question(s).', [Length(FFiltered)]);

  if Length(FFiltered) = 0 then
    ShowFinishedState
  else
    ShowCurrentQuestion;
end;

procedure TForm1.btnRetestClick(Sender: TObject);
begin
  case FRunMode of
    rmRetest:
      begin
        FRunMode := rmNormal;
        if not LoadProgress then
          ApplyFilterAndReset;
        UpdateScoreLabel;
        ShowCurrentQuestion;
        UpdateRunModeButtons;
      end;
    rmNormal:
      begin
        if FWrongIDs.Count = 0 then
        begin
          ShowMessage('No wrong answers recorded yet for this exam.');
          Exit;
        end;
        SaveProgress;
        StartRetestRun;
      end;
  end;
end;

// Builds an official-style mock exam: exactly one random question from
// every group in the currently-loaded pool (see GroupKeyOf), in random
// order. Because every pool here has exactly one exam question per group,
// this reproduces the real exam's length and composition automatically -
// 50 questions for Amateur Extra, 24 for GROL Element 1, 100 for GROL
// Element 3 - with no pool-specific table to maintain.
procedure TForm1.BuildMockExam;
var
  i, k, r, tmp, cnt: Integer;
  keys: TStringList;
  key: string;
  candidates, chosen: array of Integer;
begin
  keys := TStringList.Create;
  try
    keys.Sorted := True;
    keys.Duplicates := dupIgnore;
    for i := 0 to High(FQuestions) do
      keys.Add(GroupKeyOf(FQuestions[i].ID));

    SetLength(chosen, keys.Count);
    cnt := 0;
    for k := 0 to keys.Count - 1 do
    begin
      key := keys[k];
      SetLength(candidates, 0);
      for i := 0 to High(FQuestions) do
        if GroupKeyOf(FQuestions[i].ID) = key then
        begin
          SetLength(candidates, Length(candidates) + 1);
          candidates[High(candidates)] := i;
        end;
      if Length(candidates) > 0 then
      begin
        r := Random(Length(candidates));
        chosen[cnt] := candidates[r];
        Inc(cnt);
      end;
    end;
    SetLength(chosen, cnt);

    for k := High(chosen) downto 1 do
    begin
      r := Random(k + 1);
      tmp := chosen[k];
      chosen[k] := chosen[r];
      chosen[r] := tmp;
    end;

    SetLength(FFiltered, Length(chosen));
    for i := 0 to High(chosen) do
      FFiltered[i] := chosen[i];
  finally
    keys.Free;
  end;
end;

procedure TForm1.StartMockRun;
var
  i: Integer;
begin
  FRunMode := rmMock;
  BuildMockExam;

  SetLength(FSteps, Length(FFiltered));
  for i := 0 to High(FSteps) do
  begin
    FSteps[i].Shuffled := False;
    FSteps[i].Chosen := -1;
  end;

  FPos := 0;
  FAsked := 0;
  FCorrect := 0;
  rgChoices.Enabled := True;
  btnNext.Enabled := False;
  btnBack.Enabled := False;
  UpdateScoreLabel;
  UpdateRunModeButtons;
  lblFooter.Caption := Format('Mock exam: %d questions, need %d correct to pass.',
    [Length(FFiltered), FPools[FCurPoolIdx].ExamPass]);

  if Length(FFiltered) = 0 then
    ShowFinishedState
  else
    ShowCurrentQuestion;
end;

procedure TForm1.btnMockClick(Sender: TObject);
begin
  case FRunMode of
    rmMock:
      begin
        FRunMode := rmNormal;
        if not LoadProgress then
          ApplyFilterAndReset;
        UpdateScoreLabel;
        ShowCurrentQuestion;
        UpdateRunModeButtons;
      end;
    rmNormal:
      begin
        if MessageDlg('Start mock exam?',
          Format('This draws a %d-question mock exam (one random question per ' +
            'group, like the real exam) - need %d correct to pass. Your current ' +
            'study run is paused and resumes when you come back.',
            [GroupCount, FPools[FCurPoolIdx].ExamPass]),
          mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
          Exit;
        SaveProgress;
        StartMockRun;
      end;
  end;
end;

// ---------------------------------------------------------------------
// Error Analysis
//
// Two sets of counts per question:
//  - history: every answer ever given for this exam - study runs, retests
//    and mock exams, across program restarts. Saved after each answer to
//    error_history_<pool>.txt next to progress_<pool>.txt.
//  - round: just the current main study run (the one Restart/Reshuffle
//    starts). Not saved separately - it's rebuilt from the run's saved
//    answers whenever the run is loaded, so it survives restarts too and
//    is unaffected by retest/mock detours.
// The chart groups both by subelement: E0..E9 for Amateur Extra, and the
// official FCC subelements (1-A..1-D, 3-A..3-Q) for the GROL pools.
// ---------------------------------------------------------------------

function TForm1.AnalysisKeyOf(const q: TQuestion): string;
var
  g: string;
begin
  // Lettered pools already have a subelement (e.g. 'E5').
  if q.Sub <> '' then
    Exit(q.Sub);
  // GROL IDs look like '1-7B4' / '3-82M1': element, key topic number,
  // subelement letter, question number. Key = element + letter: '1-B'.
  g := GroupKeyOf(q.ID);
  if (Pos('-', g) > 0) and (Length(g) > 0) and (g[Length(g)] in ['A'..'Z']) then
    Result := Copy(g, 1, Pos('-', g)) + g[Length(g)]
  else
    Result := '?';
end;

function TForm1.ErrorHistoryFileName: string;
begin
  // e.g. C:\Users\<you>\AppData\Local\hamquiz\error_history_1.txt
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  ForceDirectories(Result);
  Result := Result + 'error_history_' + LowerCase(Copy(FQuestions[0].ID, 1, 1)) + '.txt';
end;

procedure TForm1.LoadErrorHistory;
var
  sl: TStringList;
  i, p1, p2, qi: Integer;
  id, line, MarkerFile: string;
  HasHistoryData: Boolean;
begin
  // Explicitly zero everything: SetLength keeps old values when the length
  // doesn't change, and two pools could have the same size.
  SetLength(FHistoryAsked, Length(FQuestions));
  SetLength(FHistoryErrors, Length(FQuestions));
  SetLength(FRoundAsked, Length(FQuestions));
  SetLength(FRoundErrors, Length(FQuestions));
  for i := 0 to High(FQuestions) do
  begin
    FHistoryAsked[i] := 0;
    FHistoryErrors[i] := 0;
    FRoundAsked[i] := 0;
    FRoundErrors[i] := 0;
  end;
  if Length(FQuestions) = 0 then
    Exit;

  // File format: one line per question answered at least once,
  //   <id>|<times answered>|<times wrong>
  if FileExists(ErrorHistoryFileName) then
  begin
    sl := TStringList.Create;
    try
      try
        sl.LoadFromFile(ErrorHistoryFileName);
        for i := 0 to sl.Count - 1 do
        begin
          line := sl[i];
          p1 := Pos('|', line);
          if p1 <= 0 then Continue;
          p2 := Pos('|', Copy(line, p1 + 1, MaxInt));
          if p2 <= 0 then Continue;
          p2 := p2 + p1;
          id := Copy(line, 1, p1 - 1);
          qi := FindQuestion(id);
          if qi < 0 then Continue;
          FHistoryAsked[qi] := StrToIntDef(Copy(line, p1 + 1, p2 - p1 - 1), 0);
          FHistoryErrors[qi] := StrToIntDef(Copy(line, p2 + 1, MaxInt), 0);
          if FHistoryAsked[qi] < 0 then FHistoryAsked[qi] := 0;
          if FHistoryErrors[qi] < 0 then FHistoryErrors[qi] := 0;
          if FHistoryErrors[qi] > FHistoryAsked[qi] then
            FHistoryErrors[qi] := FHistoryAsked[qi];
        end;
      except
        // A damaged history file should not prevent the quiz from starting.
      end;
    finally
      sl.Free;
    end;
  end;

  // One-time import of the older wrong-answer list (wrong_<pool>.txt), so
  // the chart isn't empty the first time. Each listed ID counts as one
  // answer and one error - the old list doesn't record how often. A marker
  // file makes sure this happens only once, even after a reset.
  MarkerFile := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
    'error_history_' + LowerCase(Copy(FQuestions[0].ID, 1, 1)) + '_legacy_imported.txt';
  if not FileExists(MarkerFile) then
  begin
    HasHistoryData := False;
    for i := 0 to High(FHistoryAsked) do
      if FHistoryAsked[i] > 0 then
      begin
        HasHistoryData := True;
        Break;
      end;

    if (not HasHistoryData) and FileExists(WrongFileName) then
    begin
      sl := TStringList.Create;
      try
        try
          sl.LoadFromFile(WrongFileName);
          for i := 0 to sl.Count - 1 do
          begin
            qi := FindQuestion(Trim(sl[i]));
            if qi < 0 then Continue;
            FHistoryAsked[qi] := 1;
            FHistoryErrors[qi] := 1;
          end;
          SaveErrorHistory;
        except
          // A damaged legacy list should not prevent the quiz from starting.
        end;
      finally
        sl.Free;
      end;
    end;

    sl := TStringList.Create;
    try
      sl.Add('Legacy wrong-answer list migration checked.');
      try
        sl.SaveToFile(MarkerFile);
      except
        // Not fatal; the import is simply re-checked next time.
      end;
    finally
      sl.Free;
    end;
  end;
end;

procedure TForm1.SaveErrorHistory;
var
  sl: TStringList;
  i: Integer;
begin
  if Length(FQuestions) = 0 then
    Exit;
  sl := TStringList.Create;
  try
    for i := 0 to High(FQuestions) do
      if (i <= High(FHistoryAsked)) and (FHistoryAsked[i] > 0) then
        sl.Add(FQuestions[i].ID + '|' + IntToStr(FHistoryAsked[i]) + '|' +
          IntToStr(FHistoryErrors[i]));
    try
      sl.SaveToFile(ErrorHistoryFileName);
    except
      // Not fatal: the counts just won't be remembered across restarts.
    end;
  finally
    sl.Free;
  end;
end;

procedure TForm1.RecordHistoricalAnswer(AIndex: Integer; IsWrong: Boolean);
begin
  if (AIndex < 0) or (AIndex > High(FHistoryAsked)) then
    Exit;
  Inc(FHistoryAsked[AIndex]);
  if IsWrong then
    Inc(FHistoryErrors[AIndex]);
  SaveErrorHistory;

  // Only the main study run counts towards "current study run".
  if FRunMode = rmNormal then
  begin
    Inc(FRoundAsked[AIndex]);
    if IsWrong then
      Inc(FRoundErrors[AIndex]);
  end;
end;

procedure TForm1.RebuildRoundCounts;
var
  i, qi: Integer;
begin
  // Recomputes the "current study run" counts from the run's own answers
  // (FSteps), so they're right after a restart or a retest/mock detour.
  // Only called while the main run is the one in FFiltered/FSteps.
  SetLength(FRoundAsked, Length(FQuestions));
  SetLength(FRoundErrors, Length(FQuestions));
  for i := 0 to High(FQuestions) do
  begin
    FRoundAsked[i] := 0;
    FRoundErrors[i] := 0;
  end;
  for i := 0 to Min(High(FSteps), High(FFiltered)) do
    if FSteps[i].Shuffled and (FSteps[i].Chosen >= 0) and (FSteps[i].Chosen <= 3) then
    begin
      qi := FFiltered[i];
      if (qi < 0) or (qi > High(FQuestions)) then
        Continue;
      Inc(FRoundAsked[qi]);
      if FSteps[i].Order[FSteps[i].Chosen] <> FQuestions[qi].CorrectIndex then
        Inc(FRoundErrors[qi]);
    end;
end;

procedure TForm1.btnErrorAnalysisClick(Sender: TObject);
var
  keys, Labels: TStringList;
  Errors, Asked, RoundErrors, RoundAsked: array of Integer;
  i, k: Integer;
begin
  if Length(FQuestions) = 0 then
    Exit;
  keys := TStringList.Create;
  Labels := TStringList.Create;
  try
    keys.Sorted := True;
    keys.Duplicates := dupIgnore;
    for i := 0 to High(FQuestions) do
      keys.Add(AnalysisKeyOf(FQuestions[i]));

    SetLength(Errors, keys.Count);
    SetLength(Asked, keys.Count);
    SetLength(RoundErrors, keys.Count);
    SetLength(RoundAsked, keys.Count);
    for k := 0 to keys.Count - 1 do
    begin
      Errors[k] := 0; Asked[k] := 0; RoundErrors[k] := 0; RoundAsked[k] := 0;
      Labels.Add(keys[k] + ' - ' + SubelementTitle(keys[k]));
    end;

    for i := 0 to High(FQuestions) do
    begin
      k := keys.IndexOf(AnalysisKeyOf(FQuestions[i]));
      if k < 0 then Continue;
      if i <= High(FHistoryAsked) then
      begin
        Inc(Asked[k], FHistoryAsked[i]);
        Inc(Errors[k], FHistoryErrors[i]);
      end;
      if i <= High(FRoundAsked) then
      begin
        Inc(RoundAsked[k], FRoundAsked[i]);
        Inc(RoundErrors[k], FRoundErrors[i]);
      end;
    end;

    ShowErrorChart(ExamClassName, Labels, Errors, Asked, RoundErrors, RoundAsked);
  finally
    Labels.Free;
    keys.Free;
  end;
end;

procedure TForm1.btnResetErrorHistoryClick(Sender: TObject);
var
  i: Integer;
begin
  if Length(FQuestions) = 0 then
    Exit;
  if MessageDlg('Reset Error History',
    'This permanently clears the accumulated answered/error counts for ' +
    ExamClassName + '. The other exams, your current study run and the ' +
    'Retest wrong-answer list are not affected. Continue?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  for i := 0 to High(FHistoryAsked) do
  begin
    FHistoryAsked[i] := 0;
    FHistoryErrors[i] := 0;
  end;
  SaveErrorHistory;
  ShowMessage('Error history for ' + ExamClassName + ' has been reset.');
end;

procedure TForm1.btnWhyClick(Sender: TObject);
var
  q: TQuestion;
  Letters: array[0..3] of Char;
  i, orig: Integer;
  s, note, sep: string;
begin
  // Available any time this question has explanation content - before an
  // answer is picked as well as after (the button itself is only enabled
  // when there's something to show; see HasWhyContent).
  q := FQuestions[FFiltered[FPos]];
  Letters[0] := 'A'; Letters[1] := 'B'; Letters[2] := 'C'; Letters[3] := 'D';

  if Trim(q.Explanation) <> '' then
    s := 'Why:  ' + q.Explanation
  else if HasWhyContent(q) then
    s := 'Why:'
  else
    s := 'No explanation available for this question.';

  // Optional background paragraph: the terms and procedure behind the
  // question. When it's there, the per-choice notes are single-spaced so
  // everything still fits in the explanation area.
  sep := #13#10#13#10;
  if Trim(q.Background) <> '' then
  begin
    // blank line before the first note, then one line per note
    s := s + #13#10#13#10 + 'Background:  ' + q.Background + #13#10;
    sep := #13#10;
  end;

  // One short line per choice, in the order they're shown on screen (not
  // the pool's original order) so it lines up with what the user sees -
  // a nutshell reason the right answer is right and the others are wrong.
  if HasWhyContent(q) then
    for i := 0 to 3 do
    begin
      orig := FDisplayMap[i];
      note := Trim(q.ChoiceNotes[orig]);
      if note <> '' then
      begin
        if orig = q.CorrectIndex then
          s := s + sep + Letters[i] + '.  (correct)  ' + note
        else
          s := s + sep + Letters[i] + '.  (wrong)  ' + note;
      end;
    end;

  lblExplanation.Caption := s;

  // Many explanations come with a formula card or diagram, shown in its
  // own window next to the main one (like the exam figures).
  if (q.ExplainImage <> '') and
     FileExists(FImagesDir + 'explain' + PathDelim + q.ExplainImage) then
    ShowExplainPopup(FImagesDir + 'explain' + PathDelim + q.ExplainImage,
      'Why? - ' + q.ID)
  else
    CloseExplainPopup;
end;

procedure TForm1.btnRestartClick(Sender: TObject);
begin
  if ConfirmDiscardProgress then
    ApplyFilterAndReset;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveProgress;
  // Take the figure popup down with the main window instead of leaving
  // an orphaned window open after the app quits.
  if Assigned(FFigureForm) then
    FFigureForm.Close;
  if Assigned(FExplainForm) then
    FExplainForm.Close;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FWrongIDs.Free;
end;

procedure TForm1.cmbCategoryChange(Sender: TObject);
begin
  if ConfirmDiscardProgress then
    ApplyFilterAndReset
  else
    cmbCategory.ItemIndex := FCurCat;  // keep the current run
end;

procedure TForm1.LoadPool(AIndex: Integer; AResume: Boolean);
var
  QFile: string;
begin
  QFile := ResolveDataFile(FPools[AIndex].FileName);
  if QFile = '' then
  begin
    ShowMessage('Could not find ' + FPools[AIndex].FileName + '. Please make sure it ' +
      'is in the same folder as the program executable.');
    Exit;
  end;

  try
    LoadQuestions(QFile);
  except
    on E: Exception do
    begin
      ShowMessage('Failed to load ' + FPools[AIndex].FileName + ':' + LineEnding + E.Message);
      Exit;
    end;
  end;

  FCurPoolIdx := AIndex;
  LoadErrorHistory;
  Caption := ExamClassName + ' Quiz';
  lblFooter.Caption := Format('Loaded %d questions from %s (%s)',
    [Length(FQuestions), FPools[AIndex].FileName, ExamClassName]);

  BuildCategoryList;
  FRunMode := rmNormal;
  LoadWrongList;
  UpdateRunModeButtons;

  if AResume and LoadProgress then
  begin
    UpdateScoreLabel;
    ShowCurrentQuestion;
    lblFooter.Caption := lblFooter.Caption + '  -  resumed previous run';
  end
  else
    ApplyFilterAndReset;
end;

procedure TForm1.cmbPoolChange(Sender: TObject);
var
  newIdx: Integer;
begin
  newIdx := cmbPool.ItemIndex;
  if (newIdx < 0) or (newIdx = FCurPoolIdx) then
    Exit;
  if not ConfirmDiscardProgress then
  begin
    cmbPool.ItemIndex := FCurPoolIdx;
    Exit;
  end;
  LoadPool(newIdx, True);
end;

procedure TForm1.MigrateOldDataDir;
var
  NewDir, OldDir: string;
  sr: TSearchRec;
begin
  // The program used to be called hamquiz, and its saved data (progress,
  // wrong-answer lists, error history) lives in a folder named after the
  // program - e.g. %LOCALAPPDATA%\hamquiz\. Under the new name it would
  // look in ...\radioquiz\ and find nothing. So copy over any file the new
  // folder doesn't have yet. The old folder is left as it is.
  NewDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  OldDir := IncludeTrailingPathDelimiter(
    ExtractFileDir(ExcludeTrailingPathDelimiter(NewDir))) + 'hamquiz' + PathDelim;
  if SameFileName(OldDir, NewDir) or not DirectoryExists(OldDir) then
    Exit;
  ForceDirectories(NewDir);
  if FindFirst(OldDir + '*.txt', faAnyFile and not faDirectory, sr) = 0 then
  try
    repeat
      if not FileExists(NewDir + sr.Name) then
        CopyFile(OldDir + sr.Name, NewDir + sr.Name);
    until FindNext(sr) <> 0;
  finally
    FindClose(sr);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
  resolved: string;
begin
  Randomize;
  FAnswered := False;
  FCurCat := 0;
  FCurPoolIdx := -1;
  FRunMode := rmNormal;
  FWrongIDs := TStringList.Create;
  MigrateOldDataDir;
  // Question/answer text can contain '&' (Element 7) - show it literally
  // instead of treating it as a keyboard accelerator marker.
  lblQuestion.ShowAccelChar := False;
  lblResult.ShowAccelChar := False;
  lblExplanation.ShowAccelChar := False;

  // Diagrams referenced by some questions live in an "images" folder next
  // to the pool files - resolved the same tolerant way as the pool files.
  FImagesDir := ExtractFilePath(ParamStr(0)) + 'images' + PathDelim;
  if not DirectoryExists(FImagesDir) then
    FImagesDir := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + 'images' + PathDelim;
  if not DirectoryExists(FImagesDir) then
    FImagesDir := 'images' + PathDelim;

  // Discover which exams are actually present next to the program. Any
  // pool file that's missing is simply left off the "Exam:" dropdown.
  SetLength(FPools, 0);
  for i := 0 to PoolCandidateCount - 1 do
  begin
    resolved := ResolveDataFile(PoolCandidateFile[i]);
    if resolved <> '' then
    begin
      SetLength(FPools, Length(FPools) + 1);
      FPools[High(FPools)].DisplayName := PoolCandidateName[i];
      FPools[High(FPools)].FileName := PoolCandidateFile[i];
      FPools[High(FPools)].ExamPass := PoolCandidatePass[i];
    end;
  end;

  if Length(FPools) = 0 then
  begin
    ShowMessage('Could not find questions.json. Please make sure it is in the ' +
      'same folder as the program executable.');
    Exit;
  end;

  cmbPool.Items.BeginUpdate;
  try
    cmbPool.Items.Clear;
    for i := 0 to High(FPools) do
      cmbPool.Items.Add(FPools[i].DisplayName);
  finally
    cmbPool.Items.EndUpdate;
  end;
  cmbPool.ItemIndex := 0;

  LoadPool(0, True);
end;

end.
