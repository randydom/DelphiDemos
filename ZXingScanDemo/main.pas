unit main;
{
  * Copyright 2015 E Spelt for test project stuff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.

  * Implemented by E. Spelt for Delphi
}
interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.StdCtrls, FMX.Media, FMX.Platform, FMX.MultiView, FMX.ListView.Types,
  FMX.ListView, FMX.Layouts, System.Actions, FMX.ActnList, FMX.TabControl,
  FMX.ListBox, Threading, BarcodeFormat, ReadResult,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, ScanManager, FMX.Ani
  {$IFDEF ANDROID}
  ,Androidapi.JNIBridge
  ,System.Rtti
  ,Androidapi.JNI.Hardware
  ,FMX.Media.Android
  ,CameraConfigurationUtils
  {$ENDIF}
  ;

type
  TMainForm = class(TForm)
    btnStartCamera: TButton;
    btnStopCamera: TButton;
    lblScanStatus: TLabel;
    imgCamera: TImage;
    ToolBar1: TToolBar;
    btnMenu: TButton;
    Layout2: TLayout;
    ToolBar3: TToolBar;
    CameraComponent1: TCameraComponent;
    Memo1: TMemo;
    lblStatus: TLabel;
    lytScanMask: TLayout;
    Rectangle1: TRectangle;
    Rectangle2: TRectangle;
    Rectangle3: TRectangle;
    Rectangle4: TRectangle;
    lytScanWindow: TLayout;
    Line1: TLine;
    FloatAnimation1: TFloatAnimation;
    rectLefTop: TRectangle;
    rectTopRight: TRectangle;
    rectLeftBottom: TRectangle;
    rectRightTop: TRectangle;
    rectTopLeft: TRectangle;
    rectRightBottom: TRectangle;
    Rectangle5: TRectangle;
    Rectangle6: TRectangle;
    Text1: TText;
    chkAutoFocus: TCheckBox;
    btnAvailableSettings: TSpeedButton;
    procedure btnStartCameraClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnStopCameraClick(Sender: TObject);

    procedure FormDestroy(Sender: TObject);
    procedure CameraComponent1SampleBufferReady(Sender: TObject;
      const ATime: TMediaTime);
    procedure btnAvailableSettingsClick(Sender: TObject);
  private
    { Private declarations }
    FStartTime: TDateTime;
    FScanManager: TScanManager;
    FScanInProgress: Boolean;
    frameTake: Integer;
    procedure GetImage();
    procedure FocusReady;
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;

  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}
{$R *.NmXhdpiPh.fmx ANDROID}
{$R *.LgXhdpiPh.fmx ANDROID}
{$R *.iPhone55in.fmx IOS}

type
  TMyCamera = class(TCameraComponent)

  end;

{$IFDEF ANDROID}
TAndroidCameraCallback = class(TJavaLocal, JCamera_AutoFocusCallback)
private
  [Weak] FMainForm: TMainForm;
public
  procedure onAutoFocus(success: Boolean; camera: JCamera); cdecl;
end;

procedure TAndroidCameraCallback.onAutoFocus(success: Boolean; camera: JCamera); cdecl;
begin
  FMainForm.FocusReady;
end;

var
  CameraCallBack: TAndroidCameraCallback = nil;

function GetCameraCallBack: TAndroidCameraCallback;
begin
  if CameraCallBack = nil then
    CameraCallBack := TAndroidCameraCallback.Create;

  Result := TAndroidCameraCallback.Create;
end;
{$ENDIF}

procedure TMainForm.FocusReady;
begin

end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  AppEventSvc: IFMXApplicationEventService;
begin

  lblScanStatus.Text := '';
  frameTake := 0;

  { by default, we start with Front Camera and Flash Off }
  { cbFrontCamera.IsChecked := True;
    CameraComponent1.Kind := FMX.Media.TCameraKind.ckFrontCamera;

    cbFlashOff.IsChecked := True;
    if CameraComponent1.HasFlash then
    CameraComponent1.FlashMode := FMX.Media.TFlashMode.fmFlashOff;
  }

  { Add platform service to see camera state. }
  if TPlatformServices.Current.SupportsPlatformService
    (IFMXApplicationEventService, IInterface(AppEventSvc)) then
    AppEventSvc.SetApplicationEventHandler(AppEvent);

  CameraComponent1.Quality := FMX.Media.TVideoCaptureQuality.MediumQuality;
  lblScanStatus.Text := '';
  FScanManager := TScanManager.Create(TBarcodeFormat.Auto, nil);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FScanManager.Free;
end;

procedure TMainForm.btnAvailableSettingsClick(Sender: TObject);
var
  Settings: TArray<TVideoCaptureSetting>;
  I: Integer;
  s: string;
begin
  //
  Settings := CameraComponent1.AvailableCaptureSettings;
  for I := 0 to High(Settings) do
  begin
    s := Format('%d: Width=%d, Height=%d, FrameRate=%f, Min=%f, Max=%f',
      [I+1, Settings[I].Width, Settings[I].Height,
      Settings[I].FrameRate, Settings[I].MinFrameRate, Settings[I].MaxFrameRate]);
    Memo1.Lines.Add(s);
  end;
end;

procedure TMainForm.btnStartCameraClick(Sender: TObject);
var
  Setting: TVideoCaptureSetting;
  {$IFDEF ANDROID}
  JC: JCamera;
  Device: TCaptureDevice;
  ClassRef: TClass;
  ctx: TRttiContext;
  t: TRttiType;
  Params: JCamera_Parameters;
  {$ENDIF}
begin
  FStartTime := Now;
  frameTake := 0;
  CameraComponent1.Active := False;

  Setting:= CameraComponent1.CaptureSetting;
  Setting.Width := 352;
  Setting.Height := 288;
  Setting.FrameRate := 30;
  Setting.SetFrameRate(30, 30);
  if chkAutoFocus.IsChecked then
    CameraComponent1.FocusMode := TFocusMode.ContinuousAutoFocus
  else
    CameraComponent1.FocusMode := TFocusMode.AutoFocus;
  CameraComponent1.SetCaptureSetting(Setting);
  CameraComponent1.Quality := TVideoCaptureQuality.MediumQuality;
  CameraComponent1.Kind := FMX.Media.TCameraKind.BackCamera;

  {$IFDEF ANDROID}
  Device := TMyCamera(CameraComponent1).Device;

  ClassRef := Device.ClassType;
  ctx := TRttiContext.Create;
  try
    t := ctx.GetType(ClassRef);
    JC := t.GetProperty('Camera').GetValue(Device).AsInterface as JCamera;
    TCameraConfigurationUtils.setBarcodeSceneMode(JC.getParameters);
    TCameraConfigurationUtils.setVideoStabilization(JC.getParameters);
    //JC.cancelAutoFocus();
    //GetCameraCallback().FMainForm := Self;
    //JC.autoFocus(GetCameraCallback());
  finally
    ctx.Free;
  end;
  {$ENDIF}
  CameraComponent1.Active := True;

  lblScanStatus.Text := '';
  memo1.Lines.Clear;

  lytScanMask.Visible := True;
  FloatAnimation1.StopValue := lytScanWindow.Height;
  FloatAnimation1.Start;
end;

procedure TMainForm.btnStopCameraClick(Sender: TObject);
begin
  CameraComponent1.Active := False;
  //self.imgCamera.Bitmap.Clear(0);
  FloatAnimation1.Stop;
  lytScanMask.Visible := False;
end;

procedure TMainForm.CameraComponent1SampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
  TThread.Synchronize(TThread.CurrentThread, GetImage);
end;

procedure TMainForm.GetImage;
var
  scanBitmap: TBitmap;
  ReadResult: TReadResult;
  dt: TDateTime;
  fps: double;
  w, h, x, y: Integer;
begin

  CameraComponent1.SampleBufferToBitmap(imgCamera.Bitmap, True);
  if (FScanInProgress) then
  begin
    Exit;
  end;

  inc(frameTake);
//  if (frameTake mod 4 <> 0) then
//  begin
//  Exit;
//  end;
  dt := (Now - FStartTime) * SecsPerDay;
  fps := (frameTake / dt);
  lblStatus.Text := Format('Frame:%d, FPS:%.2f', [frameTake, fps]);
  w := imgCamera.Bitmap.Width;
  h := imgCamera.Bitmap.Height;
  x := Round(w * lytScanWindow.Position.X / imgCamera.Width);
  y := Round(h * lytScanWindow.Position.Y / imgCamera.Height);

  scanBitmap := TBitmap.Create();
  scanBitmap.SetSize(w - 2 * x, h - 2 * y);
  scanBitmap.Canvas.DrawBitmap(imgCamera.Bitmap,
    RectF(x, y, w - x, h - y),
    RectF(0,0,scanBitmap.Width, scanBitmap.Height),
    1);
//  scanBitmap.Assign(imgCamera.Bitmap);

  TTask.Run(
    procedure
    begin

      try
        FScanInProgress := True;

        scanBitmap.Assign(imgCamera.Bitmap);

        ReadResult := FScanManager.Scan(scanBitmap);
        FScanInProgress := False;
      except
        on E: Exception do
        begin
          FScanInProgress := False;
          TThread.Synchronize(nil,
            procedure
            begin
              // lblScanStatus.Text := E.Message;
              // lblScanResults.Text := '';
            end);

          if (scanBitmap <> nil) then
          begin
            scanBitmap.Free;
          end;

          Exit;

        end;

      end;

      TThread.Synchronize(nil,
        procedure
        begin

          if (length(lblScanStatus.Text) > 10) then
          begin
            lblScanStatus.Text := '*';
          end;

          lblScanStatus.Text := lblScanStatus.Text + '*';

          if (ReadResult <> nil) then
          begin
            memo1.Lines.Insert(0,ReadResult.Text);
            if Memo1.Lines.Count >= 10 then
              Memo1.Lines.Clear;
          end;

          if (scanBitmap <> nil) then
          begin
            scanBitmap.Free;
          end;

          FreeAndNil(ReadResult);

        end);
    end);

end;

{ Make sure the ca mera is released if you're going away. }
function TMainForm.AppEvent(AAppEvent: TApplicationEvent;
AContext: TObject): Boolean;
begin

  case AAppEvent of
    TApplicationEvent.WillBecomeInactive:
      CameraComponent1.Active := False;
    TApplicationEvent.EnteredBackground:
      CameraComponent1.Active := False;
    TApplicationEvent.WillTerminate:
      CameraComponent1.Active := False;
  end;

end;

initialization
finalization
  //CameraCallBack.Free;
end.
