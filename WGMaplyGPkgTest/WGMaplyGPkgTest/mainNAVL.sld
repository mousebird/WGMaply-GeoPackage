<?xml version="1.0" encoding="ISO-8859-1"?>
<StyledLayerDescriptor xmlns:ogc='http://www.opengis.net/ogc' xmlns:xlink='http://www.w3.org/1999/xlink' version='1.0.0' xmlns:gml='http://www.opengis.net/gml' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation='http://www.opengis.net/sld StyledLayerDescriptor.xsd' xmlns='http://www.opengis.net/sld' >
	<NamedLayer>
		<Name><![CDATA[main.NAVL]]></Name>
		<UserStyle>
			<FeatureTypeStyle>
				<Rule>
					<Name><![CDATA[VOR]]></Name>
					<Title><![CDATA[VOR]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[1]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="VOR.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[VORTAC]]></Name>
					<Title><![CDATA[VORTAC]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[2]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="VORTAC.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[TACAN]]></Name>
					<Title><![CDATA[TACAN]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[3]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="TACAN.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[VOR-DME]]></Name>
					<Title><![CDATA[VOR-DME]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[4]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="VORDME.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[NDB]]></Name>
					<Title><![CDATA[NDB]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[5]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="NDB.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[NDB-DME]]></Name>
					<Title><![CDATA[NDB-DME]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[7]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="NDBDME.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
				<Rule>
					<Name><![CDATA[DME]]></Name>
					<Title><![CDATA[DME]]></Title>
					<ogc:Filter>
						<ogc:PropertyIsEqualTo>
							<ogc:PropertyName>TYPE</ogc:PropertyName>
							<ogc:Literal><![CDATA[9]]></ogc:Literal>
						</ogc:PropertyIsEqualTo>
					</ogc:Filter>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="DME.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAV_IDENT]]></ogc:PropertyName>
						</Label>
						<PointPlacement>
							<AnchorPoint>
								<AnchorPointX>0.5</AnchorPointX>
								<AnchorPointY>0</AnchorPointY>
							</AnchorPoint>
						</PointPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-weight" >normal</CssParameter>
							<CssParameter name="font-size" >8.25</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#000000</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
			</FeatureTypeStyle>
		</UserStyle>
	</NamedLayer>
</StyledLayerDescriptor>
