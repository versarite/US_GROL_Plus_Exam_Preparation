unit uErrorChart;

{$mode objfpc}{$H+}

// Error Analysis window: a custom-drawn bar chart of the error rate per
// subelement for the exam that's currently loaded. Two bars per row:
//   teal    - cumulative, every answer ever recorded for this exam
//             (all study runs, retests and mock exams, across restarts)
//   fuchsia - the current study run only (the one Restart/Reshuffle starts)

interface

uses
  Classes, SysUtils, LCLType, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Math;

type
  TIntArray = array of Integer;

  TErrorChartForm = class(TForm)
  private
    FLabels: TStringList;
    FErrors, FAsked, FRoundErrors, FRoundAsked: TIntArray;
    FPaint: TPaintBox;
    procedure PaintChart(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetData(const ATitle: string; ALabels: TStrings;
      const AErrors, AAsked, ARoundErrors, ARoundAsked: array of Integer);
  end;

procedure ShowErrorChart(const ATitle: string; ALabels: TStrings;
  const AErrors, AAsked, ARoundErrors, ARoundAsked: array of Integer);

implementation

const
  HeaderH = 78;   // space above the first row (title, totals, legend)
  MaxRowH = 54;
  MinRowH = 40;   // two 15px bars + 5px gap + a little air

constructor TErrorChartForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Error Analysis';
  Width := 1200;
  Height := 700;
  Position := poScreenCenter;
  Color := clWindow;
  FLabels := TStringList.Create;
  FPaint := TPaintBox.Create(Self);
  FPaint.Parent := Self;
  FPaint.Align := alClient;
  FPaint.OnPaint := @PaintChart;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TErrorChartForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

destructor TErrorChartForm.Destroy;
begin
  FLabels.Free;
  inherited Destroy;
end;

procedure TErrorChartForm.SetData(const ATitle: string; ALabels: TStrings;
  const AErrors, AAsked, ARoundErrors, ARoundAsked: array of Integer);
var
  i: Integer;
begin
  Caption := 'Error Analysis - ' + ATitle;
  FLabels.Assign(ALabels);
  SetLength(FErrors, Length(AErrors));
  SetLength(FAsked, Length(AAsked));
  SetLength(FRoundErrors, Length(ARoundErrors));
  SetLength(FRoundAsked, Length(ARoundAsked));
  for i := 0 to High(AErrors) do FErrors[i] := AErrors[i];
  for i := 0 to High(AAsked) do FAsked[i] := AAsked[i];
  for i := 0 to High(ARoundErrors) do FRoundErrors[i] := ARoundErrors[i];
  for i := 0 to High(ARoundAsked) do FRoundAsked[i] := ARoundAsked[i];

  // Tall enough for every row at full height where the screen allows
  // (GROL Element 3 has 17 subelements), otherwise rows shrink to fit.
  Height := Min(Screen.WorkAreaHeight - 60, HeaderH + FLabels.Count * MaxRowH + 30);
  FPaint.Invalidate;
end;

procedure TErrorChartForm.PaintChart(Sender: TObject);
var
  C: TCanvas;
  i, n, y, rowH, labelW, chartW, barW, rate, roundRate: Integer;
  s: string;
  histAsked, histErrors, curAsked, curErrors: Integer;
  totAsked, totErrors, totRAsked, totRErrors: Integer;

  procedure DrawBar(ATop, ARate: Integer; AColor: TColor; const AText: string);
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := clBtnFace;
    C.Pen.Color := clSilver;
    C.Rectangle(labelW, ATop, labelW + chartW, ATop + 15);
    if ARate >= 0 then
    begin
      barW := Round(chartW * ARate / 100);
      if barW > 0 then
      begin
        C.Brush.Color := AColor;
        C.Pen.Color := AColor;
        C.Rectangle(labelW, ATop, labelW + barW, ATop + 15);
      end;
    end;
    C.Brush.Style := bsClear;
    C.Font.Color := clWindowText;
    C.TextOut(labelW + chartW + 8, ATop, AText);
    C.Brush.Style := bsSolid;
  end;

  function RateText(AErr, AAsk: Integer; const AEmpty: string): string;
  begin
    if AAsk > 0 then
      Result := Format('%d%%  (%d wrong / %d answered)',
        [Round(100 * AErr / AAsk), AErr, AAsk])
    else
      Result := AEmpty;
  end;

begin
  C := FPaint.Canvas;
  C.Brush.Color := clWindow;
  C.FillRect(FPaint.ClientRect);
  C.Font.Name := 'Segoe UI';
  C.Font.Style := [];
  C.Font.Color := clWindowText;

  n := FLabels.Count;
  if n = 0 then
  begin
    C.Font.Size := 10;
    C.TextOut(16, 16, 'No subelements to display.');
    Exit;
  end;

  totAsked := 0; totErrors := 0; totRAsked := 0; totRErrors := 0;
  for i := 0 to n - 1 do
  begin
    if i < Length(FAsked) then Inc(totAsked, FAsked[i]);
    if i < Length(FErrors) then Inc(totErrors, FErrors[i]);
    if i < Length(FRoundAsked) then Inc(totRAsked, FRoundAsked[i]);
    if i < Length(FRoundErrors) then Inc(totRErrors, FRoundErrors[i]);
  end;

  C.Font.Size := 11;
  C.Font.Style := [fsBold];
  C.TextOut(16, 8, 'Error rate by subelement (lower is better)');
  C.Font.Style := [];
  C.Font.Size := 9;
  C.TextOut(16, 32, 'Overall - all attempts: ' + RateText(totErrors, totAsked, 'nothing answered yet') +
    '      current study run: ' + RateText(totRErrors, totRAsked, 'nothing answered yet'));

  C.Brush.Color := clTeal; C.Pen.Color := clTeal;
  C.Rectangle(16, 55, 30, 67);
  C.Brush.Style := bsClear;
  C.TextOut(36, 53, 'All attempts (study runs, retests and mock exams, kept across restarts)');
  C.Brush.Style := bsSolid;
  C.Brush.Color := clFuchsia; C.Pen.Color := clFuchsia;
  C.Rectangle(560, 55, 574, 67);
  C.Brush.Style := bsClear;
  C.TextOut(580, 53, 'Current study run');
  C.Brush.Style := bsSolid;

  // Label column as wide as the longest subelement name needs.
  labelW := 0;
  for i := 0 to n - 1 do
    labelW := Max(labelW, C.TextWidth(FLabels[i]));
  labelW := labelW + 32;
  chartW := FPaint.ClientWidth - labelW - 260;
  if chartW < 80 then chartW := 80;

  rowH := (FPaint.ClientHeight - HeaderH - 10) div n;
  if rowH > MaxRowH then rowH := MaxRowH;
  if rowH < MinRowH then rowH := MinRowH;

  for i := 0 to n - 1 do
  begin
    y := HeaderH + i * rowH;
    C.Font.Color := clWindowText;
    C.Brush.Style := bsClear;
    C.TextOut(16, y + 9, FLabels[i]);
    C.Brush.Style := bsSolid;

    histAsked := 0; histErrors := 0; curAsked := 0; curErrors := 0;
    if i < Length(FAsked) then histAsked := FAsked[i];
    if i < Length(FErrors) then histErrors := FErrors[i];
    if i < Length(FRoundAsked) then curAsked := FRoundAsked[i];
    if i < Length(FRoundErrors) then curErrors := FRoundErrors[i];

    if histAsked > 0 then rate := Round(100 * histErrors / histAsked)
    else rate := -1;
    if curAsked > 0 then roundRate := Round(100 * curErrors / curAsked)
    else roundRate := -1;

    // Fixed 0-100% scale keeps the rows comparable with each other.
    if rate >= 0 then
      s := Format('%d%%  (%d/%d)', [rate, histErrors, histAsked])
    else
      s := 'No history';
    DrawBar(y, rate, clTeal, s);

    if roundRate >= 0 then
      s := Format('%d%%  (%d/%d)', [roundRate, curErrors, curAsked])
    else
      s := 'Not answered';
    DrawBar(y + 19, roundRate, clFuchsia, s);
  end;
end;

procedure ShowErrorChart(const ATitle: string; ALabels: TStrings;
  const AErrors, AAsked, ARoundErrors, ARoundAsked: array of Integer);
var
  F: TErrorChartForm;
begin
  F := TErrorChartForm.Create(Application);
  try
    F.SetData(ATitle, ALabels, AErrors, AAsked, ARoundErrors, ARoundAsked);
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
