{
  Copyright 2004-2010 Michalis Kamburelis.

  This file is part of "view3dscene".

  "view3dscene" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "view3dscene" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "view3dscene"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
unit V3DSceneViewpoints;

interface

uses VectorMath, VRMLNodes, GLWindow, KambiUtils, Classes, KambiClassUtils,
  VRMLScene;

{$define read_interface}

{ Return S with newlines replaced with spaces and trimmed to
  sensible number of characters. This is useful when you
  want to use some user-supplied string (e.g. in VRML
  SFString field) in your UI (e.g. as menu or window caption). }
function SForCaption(const S: string): string;

type
  TObjectsListItem_1 = TVRMLViewpointNode;
  {$I objectslist_1.inc}
  TViewpointsList = class(TObjectsList_1)
  private
    procedure AddViewpoint(
      Node: TVRMLNode; StateStack: TVRMLGraphTraverseStateStack;
      ParentInfo: PTraversingInfo; var TraverseIntoChildren: boolean);
  private
    FBoundViewpoint: Integer;
    procedure SetBoundViewpoint(const Value: Integer);
  private
    ViewpointsRadioGroup: TMenuItemRadioGroup;
  public
    MenuJumpToViewpoint: TMenu;

    { Currently bound viewpoint (index on the list, or -1),
      used here only to make appropriate menu item "checked".

      Note: we cannot make this of TVRMLViewpointNode (which would seem
      cleaner) because the same viewpoint node may be USEd many times
      within a single scene.
      Besides, using TVRMLViewpointNode was risky anyway,
      as we could get TVRMLScene.ViewpointStack.OnBoundChanged when
      some viewpoint nodes are already freed. }
    property BoundViewpoint: Integer
      read FBoundViewpoint write SetBoundViewpoint;

    { Recalculate our list of viewpoints, also recalculating
      MenuJumpToViewpoint contents if MenuJumpToViewpoint is initialized.

      Special value Scene = @nil means no scene is loaded, so no
      viewpoint nodes exist. }
    procedure Recalculate(Scene: TVRMLScene);

    { This does part of Recalculate job: only recalculate
      MenuJumpToViewpoint contents if MenuJumpToViewpoint is initialized.
      Call this when MenuJumpToViewpoint reference changed, and you know
      that actual scene viewpoints didn't change. }
    procedure MakeMenuJumpToViewpoint;
  end;

var
  ViewpointsList: TViewpointsList;

{$undef read_interface}

implementation

uses SysUtils, KambiStringUtils;

{$define read_implementation}
{$I objectslist_1.inc}

function SForCaption(const S: string): string;
begin
  Result := SCompressWhiteSpace(S);
  if Length(Result) > 50 then
    Result := Copy(Result, 1, 50) + '...';
end;

procedure TViewpointsList.AddViewpoint(
  Node: TVRMLNode; StateStack: TVRMLGraphTraverseStateStack;
  ParentInfo: PTraversingInfo; var TraverseIntoChildren: boolean);
begin
  Add(Node as TVRMLViewpointNode);
end;

procedure TViewpointsList.Recalculate(Scene: TVRMLScene);
begin
  Count := 0;

  if (Scene <> nil) and
     (Scene.RootNode <> nil) then
    Scene.RootNode.Traverse(TVRMLViewpointNode, @AddViewpoint);

  if MenuJumpToViewpoint <> nil then
    MakeMenuJumpToViewpoint;
end;

const
  { We don't add more menu item entries for viewpoints. }
  MaxMenuItems = 20;

procedure TViewpointsList.SetBoundViewpoint(const Value: Integer);
begin
  if FBoundViewpoint <> Value then
  begin
    FBoundViewpoint := Value;

    if ViewpointsRadioGroup <> nil then
    begin
      Assert(MenuJumpToViewpoint <> nil);

      if Between(Value, 0, MaxMenuItems -1) then
        (MenuJumpToViewpoint.Entries[Value] as TMenuItemRadio).Checked := true else
        ViewpointsRadioGroup.Selected := nil;
    end;
  end;
end;

procedure TViewpointsList.MakeMenuJumpToViewpoint;
var
  Node: TVRMLViewpointNode;
  I: Integer;
  S: string;
  Viewpoint: TNodeX3DViewpointNode;
  MenuItem: TMenuItemRadio;
begin
  MenuJumpToViewpoint.EntriesDeleteAll;

  ViewpointsRadioGroup := nil;

  for I := 0 to Min(Count, MaxMenuItems) - 1 do
  begin
    if I < 10 then
      S := '_' + IntToStr(I) else
      S := IntToStr(I);
    Node := Items[I];
    S += ': ' + Node.NodeTypeName;
    if Node is TNodeX3DViewpointNode then
    begin
      Viewpoint := TNodeX3DViewpointNode(Node);
      if Viewpoint.FdDescription.Value <> '' then
        S += ' "' + SQuoteMenuEntryCaption(
          SForCaption(Viewpoint.FdDescription.Value)) + '"';
    end else
    begin
      if Node.NodeName <> '' then
        S += ' "' + SQuoteMenuEntryCaption(Node.NodeName) + '"';
    end;

    MenuItem := TMenuItemRadio.Create(S, 300 + I, I = BoundViewpoint, false);

    if I = 0 then
      ViewpointsRadioGroup := MenuItem.Group else
      MenuItem.Group := ViewpointsRadioGroup;

    MenuJumpToViewpoint.Append(MenuItem);
  end;
  MenuJumpToViewpoint.Append(TMenuSeparator.Create);
  MenuJumpToViewpoint.Append(TMenuItem.Create('Default VRML 1.0 viewpoint', 51));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Default VRML 2.0 (and X3D) viewpoint', 52));
  MenuJumpToViewpoint.Append(TMenuSeparator.Create);
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Y up, +Z dir)', 53));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Y up, -Z dir)', 54));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Y up, +X dir)', 55));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Y up, -X dir)', 56));
  MenuJumpToViewpoint.Append(TMenuSeparator.Create);
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Z up, +X dir)', 57));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Z up, -X dir)', 58));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Z up, +Y dir)', 59));
  MenuJumpToViewpoint.Append(TMenuItem.Create('Calculated viewpoint to see the scene (+Z up, -Y dir)', 60));
end;

initialization
  ViewpointsList := TViewpointsList.Create;
finalization
  FreeAndNil(ViewpointsList);
end.