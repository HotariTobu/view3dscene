{
  Copyright 2006-2018 Michalis Kamburelis.

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
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

  ----------------------------------------------------------------------------
}

{ Internal view3dscene scenes to visualize debug stuff. }
unit V3DSceneInternalScenes;

interface

uses Classes,
  CastleScene, X3DNodes, CastleBoxes, CastleVectors,
  { TDebugEdgesScene needs to access internal shape information to visualize it }
  CastleShapeInternalShadowVolumes;

type
  TInternalScene = class(TCastleScene)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TBoundingBoxScene = class(TInternalScene)
  strict private
    TransformNode: TTransformNode;
    Box: TBoxNode;
    Shape: TShapeNode;
  public
    constructor Create(AOwner: TComponent); override;
    procedure UpdateBox(const ABox: TBox3D);
  end;

  TDebugEdgesScene = class(TInternalScene)
  strict private
    BorderLines, SilhouetteLines: TLineSetNode;
    BorderCoord, SilhouetteCoord: TCoordinateNode;
    procedure AddSilhouetteEdges(const ObserverPos: TVector4;
      const ShapeTransform: TMatrix4;
      const ShapeShadowVolumes: TShapeShadowVolumes);
    procedure AddBorderEdges(
      const ShapeTransform: TMatrix4;
      const ShapeShadowVolumes: TShapeShadowVolumes);
  public
    constructor Create(AOwner: TComponent); override;
    procedure UpdateEdges(const SourceScene: TCastleScene);
  end;

implementation

uses SysUtils,
  CastleColors, CastleShapes, CastleTriangles, CastleUtils;

{ TInternalScene ------------------------------------------------------------- }

constructor TInternalScene.Create(AOwner: TComponent);
begin
  inherited;
  Collides := false;
  Pickable := false;
  CastShadowVolumes := false;
  ExcludeFromStatistics := true;
  { Otherwise bbox from previous scene would affect AssignDefaultCamera
    and AssignDefaultNavigation calls done right after new scene is loaded. }
  InternalExcludeFromParentBoundingVolume := true;
end;

{ TBoundingBoxScene ---------------------------------------------------------- }

constructor TBoundingBoxScene.Create(AOwner: TComponent);
var
  Root: TX3DRootNode;
  Material: TUnlitMaterialNode;
  Appearance: TAppearanceNode;
begin
  inherited;

  Box := TBoxNode.Create;

  Material := TUnlitMaterialNode.Create;
  Material.EmissiveColor := GreenRGB;

  Appearance := TAppearanceNode.Create;
  Appearance.ShadowCaster := false;
  Appearance.Material := Material;

  Shape := TShapeNode.Create;
  Shape.Geometry := Box;
  Shape.Shading := shWireframe;
  Shape.Appearance := Appearance;

  TransformNode := TTransformNode.Create;
  TransformNode.AddChildren(Shape);

  Root := TX3DRootNode.Create;
  Root.AddChildren(TransformNode);

  Load(Root, true);
end;

procedure TBoundingBoxScene.UpdateBox(const ABox: TBox3D);
begin
  Shape.Render := not ABox.IsEmpty;
  if Shape.Render then
  begin
    TransformNode.Translation := ABox.Center;
    Box.Size := ABox.Size;
  end;
end;

{ TDebugEdgesScene ----------------------------------------------------------- }

constructor TDebugEdgesScene.Create(AOwner: TComponent);
var
  Root: TX3DRootNode;
  Shape: TShapeNode;
  BorderMaterial, SilhouetteMaterial: TMaterialNode;
begin
  inherited;

  Root := TX3DRootNode.Create;

  BorderLines := TLineSetNode.Create;

  BorderMaterial := TMaterialNode.Create;
  BorderMaterial.EmissiveColor := Vector3(0, 0, 1);

  Shape := TShapeNode.Create;
  Shape.Geometry := BorderLines;
  Shape.Material := BorderMaterial;
  Root.AddChildren(Shape);

  Shape.Appearance.LineProperties := TLinePropertiesNode.Create;
  Shape.Appearance.LineProperties.LineWidthScaleFactor := 3;

  BorderCoord := TCoordinateNode.Create;
  BorderLines.Coord := BorderCoord;

  SilhouetteLines := TLineSetNode.Create;

  SilhouetteMaterial := TMaterialNode.Create;
  SilhouetteMaterial.EmissiveColor := Vector3(1, 1, 0);

  Shape := TShapeNode.Create;
  Shape.Geometry := SilhouetteLines;
  Shape.Material := SilhouetteMaterial;
  Root.AddChildren(Shape);

  SilhouetteCoord := TCoordinateNode.Create;
  SilhouetteLines.Coord := SilhouetteCoord;

  Load(Root, true);
end;

procedure TDebugEdgesScene.UpdateEdges(const SourceScene: TCastleScene);
var
  ObserverPos: TVector4;
  ShapeList: TShapeList;
  Shape: TShape;
begin
  if World.MainCamera = nil then Exit;
  ObserverPos := Vector4(World.MainCamera.Position, 1);

  BorderLines.FdVertexCount.Items.Clear;
  BorderCoord.FdPoint.Items.Clear;
  SilhouetteLines.FdVertexCount.Items.Clear;
  SilhouetteCoord.FdPoint.Items.Clear;

  ShapeList := SourceScene.Shapes.TraverseList({ OnlyActive } true, { OnlyVisible } true);
  for Shape in ShapeList do
  begin
    AddSilhouetteEdges(ObserverPos, Shape.State.Transformation.Transform, Shape.InternalShadowVolumes);
    AddBorderEdges(Shape.State.Transformation.Transform, Shape.InternalShadowVolumes);
  end;

  ChangedAll;
end;

procedure TDebugEdgesScene.AddSilhouetteEdges(const ObserverPos: TVector4;
  const ShapeTransform: TMatrix4;
  const ShapeShadowVolumes: TShapeShadowVolumes);

{ This is actually a modified implementation of
  TCastleScene.RenderSilhouetteShadowQuads: instead of rendering
  shadow quad for each silhouette edge, the edge is simply added to list. }

var
  Triangles: TTriangle3List;
  EdgePtr: PManifoldEdge;

  procedure RenderEdge(
    const P0Index, P1Index: Cardinal);
  var
    V0, V1: TVector3;
    EdgeV0, EdgeV1: PVector3;
    TrianglePtr: PTriangle3;
  begin
    TrianglePtr := Triangles.Ptr(EdgePtr^.Triangles[0]);
    EdgeV0 := @TrianglePtr^.Data[(EdgePtr^.VertexIndex + P0Index) mod 3];
    EdgeV1 := @TrianglePtr^.Data[(EdgePtr^.VertexIndex + P1Index) mod 3];

    V0 := ShapeTransform.MultPoint(EdgeV0^);
    V1 := ShapeTransform.MultPoint(EdgeV1^);

    SilhouetteCoord.FdPoint.Items.AddRange([V0, V1]);
    SilhouetteLines.FdVertexCount.Items.Add(2);
  end;

  function PlaneSide(const T: TTriangle3): boolean;
  var
    Plane: TVector4;
  begin
    Plane := TrianglePlane(
      ShapeTransform.MultPoint(T.Data[0]),
      ShapeTransform.MultPoint(T.Data[1]),
      ShapeTransform.MultPoint(T.Data[2]));
    Result := (Plane.Data[0] * ObserverPos.Data[0] +
               Plane.Data[1] * ObserverPos.Data[1] +
               Plane.Data[2] * ObserverPos.Data[2] +
               Plane.Data[3] * ObserverPos.Data[3]) > 0;
  end;

var
  I: Integer;
  TrianglePtr: PTriangle3;
  PlaneSide0, PlaneSide1: boolean;
  TrianglesPlaneSide: TBooleanList;
  Edges: TManifoldEdgeList;
begin
  Triangles := ShapeShadowVolumes.TrianglesListShadowCasters;
  Edges := ShapeShadowVolumes.ManifoldEdges;

  TrianglesPlaneSide := TBooleanList.Create;
  try
    { calculate TrianglesPlaneSide array }
    TrianglesPlaneSide.Count := Triangles.Count;
    TrianglePtr := PTriangle3(Triangles.List);
    for I := 0 to Triangles.Count - 1 do
    begin
      TrianglesPlaneSide.L[I] := PlaneSide(TrianglePtr^);
      Inc(TrianglePtr);
    end;

    { for each edge, possibly render it's shadow quad }
    EdgePtr := PManifoldEdge(Edges.List);
    for I := 0 to Edges.Count - 1 do
    begin
      PlaneSide0 := TrianglesPlaneSide.L[EdgePtr^.Triangles[0]];
      PlaneSide1 := TrianglesPlaneSide.L[EdgePtr^.Triangles[1]];

      if PlaneSide0 <> PlaneSide1 then
        RenderEdge(0, 1);

      Inc(EdgePtr);
    end;

  finally FreeAndNil(TrianglesPlaneSide) end;
end;

procedure TDebugEdgesScene.AddBorderEdges(
  const ShapeTransform: TMatrix4;
  const ShapeShadowVolumes: TShapeShadowVolumes);
var
  Triangles: TTriangle3List;
  EdgePtr: PBorderEdge;

  procedure RenderEdge;
  var
    V0, V1: TVector3;
    EdgeV0, EdgeV1: PVector3;
    TrianglePtr: PTriangle3;
  begin
    TrianglePtr := Triangles.Ptr(EdgePtr^.TriangleIndex);
    EdgeV0 := @TrianglePtr^.Data[(EdgePtr^.VertexIndex + 0) mod 3];
    EdgeV1 := @TrianglePtr^.Data[(EdgePtr^.VertexIndex + 1) mod 3];

    V0 := ShapeTransform.MultPoint(EdgeV0^);
    V1 := ShapeTransform.MultPoint(EdgeV1^);

    BorderCoord.FdPoint.Items.AddRange([V0, V1]);
    BorderLines.FdVertexCount.Items.Add(2);
  end;

var
  I: Integer;
  Edges: TBorderEdgeList;
begin
  Triangles := ShapeShadowVolumes.TrianglesListShadowCasters;
  Edges := ShapeShadowVolumes.BorderEdges;

  { for each edge, render it }
  EdgePtr := PBorderEdge(Edges.List);
  for I := 0 to Edges.Count - 1 do
  begin
    RenderEdge;
    Inc(EdgePtr);
  end;
end;

end.
