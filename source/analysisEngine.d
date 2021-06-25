module analysisEngine;

import field;
import neuron;

import std.stdio;
import std.conv;
import std.format;
import std.math;
import std.algorithm;
import std.net.curl;
import std.json;
import dlib.image;
import std.path;
import std.array;
import std.net.curl;
import core.stdc.stdlib;
import core.exception;
import std.datetime;
import std.file;
import opmix.dup;
import std.parallelism;

class geoEngine  {

	this(){}
	~this(){}


public :

	void * dataSet ;
	int[] convexHull;	
	string fileName;
	
	string subCategory = "irrevelant";

	double maxLineDist			= 10;																		// i have increased the distance, because some files DO have 20+ meter of distance.
																											// more than 30 meters wont work.
	double minSectorLength 		= 15;																		// this is a length of a neurone. so I ignore it for now
	double maxDeviation_ofAngle = 10.00 ;																	// as discussed, 15 degrees is a good guess. 10 will be perfect
	double maxLineLengthOvershotRatio = 0.1;																// currently not used.
	double maxLineOutlierCount  =  3;																		// this WAS max number of outlying points from a line.
																											// I have changed this to a distance . Unit : meters
	double minLineLength		=  4;																		// minimum length of the line in meters.
	int maxTurnLineLength		=  5;
	int maxTurnLineLength_inMeter=20;
	int    minLineCount         =  4;																		// minimum number of lines in the field. I should set this to 3.
	int    minLineCount_forTrim =  2;																		// a parameter to trim the streets.
	int minLineCount_nearVertex =  5;																		// another line to trim the streets
	double crad                 =  5;																		// a threshhold distance
	double minCrossLineLength   = 10;																		// minimum length of a line that will be considered a cross-line at field boundaries
	double maxTurnRadius		= 15;																		// if you have more than this much of a line, then consider this a possible parallel line
	double minTurnRadius		=  5;																		// if you have less than this much of a line, then consider this a possible perturbation
	ulong maxMeridianSections   = 50;																		// how many sections on the field to find the boundary?
	double maxNearFieldTurnDist	=  5;																		// turn lines has to be this close ...
	double maxRMSError          =  5.00;																	// if more than this much RMS error - reject it
	double maxRoadWidth			= 10.00;																	// a road can be this wide. any more than this, and you have a field
	double maxRoadWidth_single	=  1.00;
	int maxJoinerLength			=  2;																		//
	double maxTurnThreshold 	= 15.00;																	// after 20 degrees, it is definitely a turn ...
	double turnStraightRatio 	=  0.25;
	double crossLineThreshold	=  0.5;
	double shrinkstep 			= 5.00 / 150000;
	double maxPointDist			=  2.00;																	// if point distance is larger than this, add new points inbetween
	double typicalPointDist		=  2.00 ;																	// typical point distance is 2 meters, but i set ot to half a meter just to have better resolution
	int hookTestLength			= 20;																		// if more than these many points, test for hook
	double hookTurnThreshold	= 55;																		// if more than 35 degrees of difference at opening and closing, surely a hook
	int maxTrendOutliers		=  5;																		// recalculate by dropping this many outliers.
	double maxParallelOffset 	= 20.00;																	// within these many degrees, consider them parallel.
	double maxParallelOffset_fld= 30.00;
	int min_closebyLines		=  5;
	double maxField_toFieldDistance= 10;
	double narrowRoadWidth		= 15;
	double unacceptableBurst	= 80;																		// below 50 meters .... o.k.

	double trendLikelyhood_initialGuess 	= 0.9;															// if something seems to be a segment that shows a trend,
																											// then the probability that is is truely a trend = 0.9
	double notrendLikelyhood_initialGuess 	= 0.9;															// if it seems to be not a segment that will show a trend,
																											// then the likelyhood of the guess to be true = 0.9

	double angularResolution    = 0.1;
	double minSpatialResolution = 2;
	double lineLengthScoreAmplifier		= 4;
	double lineLengthScoreWeight        = 10;
	double lineLengthScoreBias			= 0.2;
	double stripeThinnessScoreAmplifier = 100;
	double stripeThinnessScoreWeight	= 12;
	double stripeThinnessScoreBias 		= 2;
	
	
	string default_maxDrivingFluctuation = "10";
	int maxMergeAttempts = 150;
	int maxBoundaryReductionSteps = 5000;
	int maxBoundaryReductionSteps_Higherlev = 10;
	
	double transportCircleRadius= 20;
	double minPointDistance = 2.0;
	double max_interTankdistance = 40;
	double transport_fieldThreshhold = 250;
	int    transport_xgressLength= 15;
	double loadingPointThreshold = 10.0;
	int holeClosingThreshhold 	 = 2;
	
	double workWidth            = 580;
	double geoFenceRadius       = 200;
	double[] geoFenceCoordinates= new double [] (0);
	double geoFenceRadiusThreshhold = 50;
	
	int    trendAveragingLength = 10;
	double parallelThreshholdResolution = 0.1;
	double maximumAllowedNonParallelism = 80;
	double minOverlap           = 0.05;
	
	double scoreCutOff          = 1.7;
	
	enum possibleDatum : int  {WGS1984};
	
	possibleDatum actualDatum = possibleDatum.WGS1984;
	
	
	
	void set_dataType(int typ) {																			// JUST a set function. no corresponding get function
		switch (typ)  {
		
			case 1:
			case 2:
				this.dataType_current = 2;
			break;
			default :
			break;

		}
	}
	
	void calculate_drawingParams() {																		// no arguments,
																				// this will automatically take the main dataset

		switch (this.dataType_current) {

			case 1 :															// two arrays, with X and Y
			case 2 :															// geodata 
				
				double latMax  = -90;
				double latMin  =  90;
				double lonMax  =-180;
				double lonMin  = 180;
				
				int leftMostPos;
				
				field.rawData [] * rd ;
				rd = cast (field.rawData [] *)  dataSet;						// rawData rd is the complete dataset of all points

				foreach (point; *rd) {											// each point has 
																				// one lat, one lon, one time string, one satcount.
																				// point type is field.rawData
					if (point.lat > latMax)		latMax = point.lat;
					if (point.lat < latMin)		latMin = point.lat;
					if (point.lon > lonMax)		lonMax = point.lon;
					if (point.lon < lonMin)		lonMin = point.lon;
																				// writeln( "Boundary found : " ~ format("%.*g", 18, latMax) ~ "; " ~ format("%.*g", 18, lonMax) ~ "; " ~ format("%.*g", 18,latMin) ~ "; " ~  format("%.*g", 18,lonMin) ~ "; ");
				}
				
				double latDiff = latMax - latMin;
				double lonDiff = lonMax - lonMin;
				
				this.latMin_global = latMin;
				this.latMax_global = latMax;
				this.lonMin_global = lonMin;
				this.lonMax_global = lonMax;
				
				this.latdiff_global = latDiff;
				this.londiff_global = lonDiff;
				
			break;
			default:
			break;
		}
	}
	
	void create_map_fromRawData_inDLIB (double width, double height) {
	


		if(width == -1)  {width  = this.londiff_global*1.1;}
		if(height == -1) {height = this.latdiff_global*1.1;}												// automatic mode engaged
																											//writeln([width,height]);
		double multiplier = 1;


		if (width < 0.1 || height < 0.1 ) {																	// writeln("width and height too small need rescale..");

			multiplier = 100000;																			// write("image width is : ");writeln(width);
			width = width * multiplier *cos(this.latMin_global * 3.141592 / 180.00);						// write("image height is: ");writeln(width);
			height = height * multiplier;
			if ( height == 0) height = 100;
			if (width == 0) width = 100;
			//width = 100; height = 100;
		}
		else if (width < 1 || height < 1 ) {

			multiplier = 100000;
			width =  width* multiplier *cos(this.latMin_global * 3.141592 / 180.00);
			height = height * multiplier;
			if ( height == 0) height = 100;
			if (width == 0) width = 100;
			//width = 100; height = 100;
		}


		this.height_global = to!uint( height);
		this.width_global  = to!uint(width);

		this.multiplier_global = multiplier;

																											// write("diffs are: ");writeln([this.londiff_global, this.latdiff_global]);
																											// write("recheck dimensions - those are: ");writeln([width,height]);

// 		foreach(y; 0 .. image.height){
// 			foreach(x; 0 .. image.width){
// 				image[x,y] = Color4f(0.1,0.1,0.1,1);
// 			}
// 		}

		double offsetY = londiff_global * 0.05 * multiplier;
		double offsetX = latdiff_global * 0.05 * multiplier;

	}

	void analyze_tillage() {
	
		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		try {

																											//writeln(this.maxDeviation_ofAngle); // // readln;
																											// writeln(this.maxLineDist); // readln;
			add_missingPoints();																			// write("this. dataSet is : "); writeln(this.dataSet);

			rd = cast (field.rawData [] *)  this.dataSet;
																											// writeln("adding missing points done"); write("waypoints count : "); writeln((*rd).length); // readln();

																											/+
																											for (int i = 0; i < (*rd).length -1; i++) {

																												write(toStringLikeInCSharp((*rd)[i].lat )) ;
																												write( " ~ ");
																												write(toStringLikeInCSharp((*rd)[i].lon )) ;
																												writeln("");

																											}
																											+/
			get_allLines();																					writeln("getting LINES done");
			add_turnLines();																				writeln("adding turn lines..");
			mark_allSweeps();																				writeln("sweeps Completed. At this stage, if the field itself has curves");
																											writeln("there may be errors in turn detection");
																											// draw_map(); writeln(this.sweeps);// readln;
																											// writeln(this.maxLineDist); // readln;
			get_fieldSweeps();																				 writeln("field sweeps detected..."); //readln();//draw_map();// readln;

			//update_map();
																											// draw_map();  // readln;
																											// writeln(this.maxLineDist); // readln;


																											//// DONT DELETE THIS

																											// write("initial count of fields : "); writeln(this.baseFields.length);


			update_map();																						writeln(this.subCategory); // readln;


			for( int i = 0; i < this.baseFields.length; i++) {

				auto gfield = this.baseFields[i];																write(i); write(" : field is :");writeln(gfield);

				for (int ii = 0; ii < gfield.length ; ii ++) {													// writeln("drawing line : " ~ to!string(i));
																												// write("direction was :"); writeln(calculate_sweepHeading(guessedField[ii]) * 180/PI	);

					auto s = this.sweeps[gfield[ii]];															//writeln(s);// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

					for (int j = 0; j < s.length; j++) {



						auto p0 = (*rd) [this.allLines[s[j]][0]];
						auto p1 = (*rd) [this.allLines[s[j]][1]];



						double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
						auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

						if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
						if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						/+
																										// this is for ...… drawing the inner line segments in a single interpolated straight line
						for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

							auto pp1 = (*rd) [ij];
							auto pp2 = (*rd) [ij+1];

							double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
							double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
							double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
							auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
							auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

							if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



						}
						+/


					}



				}																								// readln;

			}																								draw_map();

		} catch (RangeError ) {

			// field.rawData [] * rd ;
			rd = cast (field.rawData [] *)  dataSet;


			for (int i = 0; i < (*rd).length -1; i++) {

				this.allLines ~= [i, i+1];
				this.allRedLines ~= to!int(this.allLines.length - 1);
			}


		}

	}







	//////////////////////////////////////////////////////////////////////////

	void update_map() {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;								// rawData rd is the complete dataset of all points

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;		//writeln(this.fieldBoundaries);

		auto image = new Image!(IntegerPixelFormat.RGB8)(to!int(width_global), to!int(height_global));
																				// write("after conversion to int : ");writeln([to!int(width_global), to!int(height_global)]);


		foreach (point; *rd) {													// each point has
																				// one lat, one lon, one time string, one satcount.
																				// and one UNIQUE ID
																				// point type is field.rawData
			int mapy = to!int(this.multiplier_global * (this.latMax_global - point.lat) + offsetX);
			int mapx = to!int((this.multiplier_global * (point.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));

			image[mapx,mapy] = Color4f(0,0,0,0);								// write("drawing");writeln([mapx,mapy]);

		}


		this.map = image;
		this.mapCopy = image;

	}

	void draw_map() {
		writeln("waiting to finish drawing"); savePNG(this.map, fileName~".png"); writeln("check map: "~fileName ~".png");
	}
	
	void drawLine_png(Image!(IntegerPixelFormat.RGB8) img, Color4f color, int x1, int y1, int x2, int y2) {
		int dx = x2 - x1;														//writeln(0);
		int ix = (dx > 0) - (dx < 0);											//writeln(0);
		int dx2 = std.math.abs(dx) * 2;											//writeln(0);
		int dy = y2 - y1;														//writeln(0);
		int iy = (dy > 0) - (dy < 0);											//writeln(0);
		int dy2 = std.math.abs(dy) * 2;
		img[x1, y1] = color;
																				//writeln(0);
		if (dx2 >= dy2)
		{																		//writeln(1);
			int error = dy2 - (dx2 / 2);
			while (x1 != x2)
			{
				if (error >= 0 && (error || (ix > 0)))
				{
					error -= dx2;
					y1 += iy;
				}

				error += dy2;
				x1 += ix;
				img[x1, y1] = color;
			}
		}
		else
		{																		//writeln(2);
			int error = dx2 - (dy2 / 2);
			while (y1 != y2)
			{
				if (error >= 0 && (error || (iy > 0)))
				{
					error -= dy2;
					x1 += ix;
				}

				error += dx2;
				y1 += iy;
				img[x1, y1] = color;
			}
		}
	}

	//////////////////////////////////////////////////////////////////////////


	void add_missingPoints() {																				// insert points if there are large gaps between points

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;
		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;									// writeln(this.fieldBoundaries);


		int maxProcessorCoreCount = 4;																		// set this parameter function by funtion.
																											// do not use a default parameter as this may corrupt the code.

		int totalC = to!int((*rd).length);

		int st0 = 0;
		int en0 = to!int(floor(totalC / 4.00)) - 1;

		int st1 = en0 + 1;
		int en1 = 2 * (en0 +1) -1;

		int st2 = en1 + 1;
		int en2 = 3 * (en0 +1) -1;

		int st3 = en2 + 1;
		int en3 = totalC - 1;																				// writeln([st0, en0, st1, en1, st2, en2, st3, en3]);

		field.rawData [] rd0 = (*rd) [ st0 .. en0 +1 + 1];													// OVERLAP by One. Then we will rewrite the place
		field.rawData [] rd1 = (*rd) [ st1 .. en1 +1 + 1];
		field.rawData [] rd2 = (*rd) [ st2 .. en2 +1 + 1];
		field.rawData [] rd3 = (*rd) [ st3 .. en3 +1 ];														// cant go one more here !

		auto rd_parallelSplits = [rd0, rd1, rd2, rd3];

		foreach (ii, rd_split ; parallel(rd_parallelSplits)) {												// splitted the rd array


			for ( int i = 0; i < rd_split.length -1; i++) {

				auto p1 = rd_split[i];
				auto p2 = rd_split[i+1];

				auto d = calculate_geoDistance(p1.lat, p2.lat, p1.lon,p2.lon);								// writeln(d);
				if( d > this.maxPointDist) {																// gap found

					auto pnts  = new field.rawData[] (0);													// initializing empty array of rawdata (structs for waypoints
					for(double dt = this.typicalPointDist; dt < d; dt += this.typicalPointDist) {			// stepping from start to end

						auto p = calculate_geoPoint_atDistance_andAngle(p1, dt, p2);						// picked a point at distace dt, from point p1, going towards p2
						field.rawData wp;																	// initialized struct (no new keyword needed) for waypoint

						wp.idRaw = "-";
						wp.id = -1;

						wp.lat= p[1];
						wp.lon= p[0];

						wp.satcount = p1.satcount;
						wp.datestr  = p1.datestr;

						pnts ~= wp;

					}

					rd_split.insertInPlace(i+1, pnts);														// insert them all

					i = i + to!int(pnts.length)-1;															// have to go back 1
				}

				rd_parallelSplits[ii] = rd_split;

			}

		}
																											// write(toStringLikeInCSharp((*rd)[0].lat));
																											// write(" ~ "); write(toStringLikeInCSharp((*rd)[$-1].lat));
																											// write(" ~ "); write(toStringLikeInCSharp((*rd)[(*rd).length - 1].lat));
																											// writeln(" ");

																											// write("length of rd0 is : "); writeln(rd_parallelSplits[0].length);
																											// write(" ~ "); write(toStringLikeInCSharp(rd0[0].lat));writeln(" ");
																											// write("length of rd1 is : "); writeln(rd_parallelSplits[1].length);
																											// write("length of rd2 is : "); writeln(rd_parallelSplits[2].length);
																											// write("length of rd3 is : "); writeln(rd_parallelSplits[3].length);
																											// write("length of rd0 is : "); writeln(rd_parallelSplits[0].length);
																											// write(" ~ "); write(toStringLikeInCSharp(rd3[rd3.length-1].lat));writeln(" ");

		field.rawData [] rd_flattened = rd_parallelSplits[0][0 .. $ -1] ~ rd_parallelSplits[1][0 .. $ -1] ~ rd_parallelSplits[2][0 .. $ -1] ~ rd_parallelSplits[3][0 .. $ ] ;
																											// write("length of rd flattened is : "); writeln(rd_flattened.length);


																											/+
																											for (int i = 0; i < rd_flattened.length; i++) {

																												write(toStringLikeInCSharp(rd_flattened[i].lat )) ;
																												write( " ~ ");
																												write(toStringLikeInCSharp(rd_flattened[i].lon )) ;
																												writeln("");

																											}

																											writeln("_________________");
																											for (int i = 0; i < (*rd).length; i++) {

																												write(toStringLikeInCSharp( (*rd)[i].lat )) ;
																												write( " ~ ");
																												write(toStringLikeInCSharp( (*rd)[i].lon )) ;
																												writeln("");

																											}
																											+/
																											// overlaped points overwritten !

																											// writeln(typeof(rd_flattened).stringof);
		this.dataSet = & rd_flattened;																		// taken the pointer
		rd = cast (field.rawData [] *)  dataSet;
//
//
//
// 		// now, check between en1 and st2
//
// 		// now, check between en2 and st3
//
//
//
//
//
//
//
		/+


		for (int i = 0; i < (*rd).length-1; i++) {															// writeln(i);

			auto p1 = (*rd)[i];
			auto p2 = (*rd)[i+1];
			auto d = calculate_geoDistance(p1.lat, p2.lat, p1.lon,p2.lon);									// writeln(d);
			if( d > this.maxPointDist) {																	// gap found

				auto pnts  = new field.rawData[] (0);														// initializing empty array of rawdata (structs for waypoints
				for(double dt = this.typicalPointDist; dt < d; dt += this.typicalPointDist) {				// stepping from start to end

					auto p = calculate_geoPoint_atDistance_andAngle(p1, dt, p2);							// picked a point at distace dt, from point p1, going towards p2
					field.rawData wp;																		// initialized struct (no new keyword needed) for waypoint

					wp.idRaw = "-";
					wp.id = -1;

					wp.lat= p[1];
					wp.lon= p[0];

					wp.satcount = p1.satcount;
					wp.datestr  = p1.datestr;

					pnts ~= wp;

				}

				(*rd).insertInPlace(i+1, pnts);																// insert them all

				i = i + to!int(pnts.length)-1;																// have to go back 1
			}

		}																									// writeln("completed recovering points...");



		+/

																											// write("length of rd is : "); writeln((*rd).length);
		foreach (i, r; parallel(*rd)) {																		//writeln(i);

			(*rd)[i].id = to!int(i);
			(*rd)[i].idRaw = to!string(i);

		}


		this.rd_raw = (*rd);
		this.dataSet = &rd_raw;
		//rd = cast (field.rawData [] *)  dataSet;															write("function add missing points exiting with length of rd is : "); writeln((*rd).length);
		//																									write("this. dataSet is : "); writeln(this.dataSet);

	}																										// function add missing point ends here ...
	

	void get_allLines() {																					// writeln("getallline called...");


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		int startIdx = 0;


		int d;
		int dlast;
		int trLength;
		double dst;

		dlast = 0;

		d = min( (*rd).length , this.trendAveragingLength);
		int[] firstLine = [0, d-1];


		double[] x = new double [] (0);
		double[] y = new double [] (0);
		double[] allheadings = new double [] (0);


		for ( int di = 0; di < d; di ++)
			dst += calculate_geoDistance ((*rd)[dlast+di].lat, (*rd)[dlast+di+1].lat, (*rd)[dlast+di].lon, (*rd)[dlast+di+1].lon);

		do {																								// you need a minimum length for smooth averaging

			if(dlast+d >=(*rd).length-1) break;

			d ++;

			for ( int di = 0; di < d; di ++)
				dst += calculate_geoDistance ((*rd)[dlast+di].lat, (*rd)[dlast+di+1].lat, (*rd)[dlast+di].lon, (*rd)[dlast+di+1].lon);

		}while(dst < this.minLineLength);

		for (int i = 0; i < d; i++) {

			x ~= (*rd)[i].lon;
			y ~= (*rd)[i].lat;																				// x, y properly switched for lat & lon

		}
																											//writeln("t1");
		double firstLineHeading = calculate_geoLineFit_angle_raw_withSign(x, y);							// writeln(firstLineHeading);//writeln("t1 end");

		allheadings ~= firstLineHeading;

		auto previousLine = firstLine.gdup;
		auto previousHeading = firstLineHeading;															// write("prev heading was ..");writeln(previousHeading);

		while(true) {																						//writeln("loop");


			/+ +++++++++
			++ pick the next N points
			++ get the heading
			+/

			x = new double [] (0);
			y = new double [] (0);																			// x and y wiped off ....

			dlast = d;																						//writeln(d);
			if ( d >= (*rd).length-1) break;



			d = min( (*rd).length - d , this.trendAveragingLength);											// write("d values are :");writeln(dlast);writeln(d);

			if (d == 0) {																					// there is no current heading, can't move any further
																											// insert into all lines
				break;																						// break
			}

			if (dlast + d >= (*rd).length) {

				break;
			}

																											//write((*rd).length); write (" ; "); write(dlast +d); write(" ; ");writeln(dlast);
			for ( int di = 0; di < d; di ++)
				dst += calculate_geoDistance ((*rd)[dlast+di].lat, (*rd)[dlast+di+1].lat, (*rd)[dlast+di].lon, (*rd)[dlast+di+1].lon);

			int straightD = d;																				//writeln("t2");

			do {

				if(dlast+d >=(*rd).length-1) break;															// - 1, because max value of d may reach (*rd).length.

				// if a hook is found, break;

				/+
				if ( d > this.hookTestLength) {

					double [] xx = new double[] (0);
					double [] yy = new double[] (0);




					auto he = new double[] (0);

					for (int kk = dlast;  kk < d+dlast - to!int(d/2); kk++){
						for (int k = kk; k < kk+ to!int(d/2);  k++) {

							xx ~= (*rd)[k].lon;
							yy ~= (*rd)[k].lat;																// x, y properly switched for lat & lon

						}																					//writeln(xx);writeln(yy);
						auto he_raw = calculate_geoLineFit_angle(xx,yy);									//writeln("maybe");
						if (he_raw < 0) he_raw = he_raw + (PI*2);											// add 360 to make it the same clock direction of measure
						he ~= he_raw;
						xx.length = 0;
						yy.length = 0;
					}

					auto returns = false;

					he_check: for ( int ik = 0; ik < he.length; ik ++) {

						for ( int jk = 0; jk < he.length; jk ++) {

							if (ik == jk) continue;
							auto diff = abs ( he[ik]-he[jk]) ;
							diff = diff > PI ?  2*PI - diff : diff;
							if (diff > this.maxTurnThreshold * PI / 180.00) {
								returns = true;
								break he_check;
							}
						}

					}

					if (returns) break;																		// max turn occured between first half and second half, or path returns
																											// but this is ONLY sensitive to the case if hook appears at the beginning.
																											// if hook appears at the end, then we have a problem
					// else straightD = d;																	// useless !

				}
				+/



				d ++;

				for ( int di = 0; di < d; di ++)
					dst += calculate_geoDistance ((*rd)[dlast+di].lat, (*rd)[dlast+di+1].lat, (*rd)[dlast+di].lon, (*rd)[dlast+di+1].lon);

			}while(dst < this.minLineLength);																// you need a minimum length for smooth averaging
																											//writeln("t2 end");

			// if (straightD > this.hookTestLength) d = straightD;											// useless

																											//writeln("t3");
			for (int i = dlast; i < d+dlast; i++) {

				x ~= (*rd)[i].lon;
				y ~= (*rd)[i].lat;																			// x, y properly switched for lat & lon

			}																								//writeln("t3 end");writeln(x);writeln(y);
																											//writeln("t4");
			auto lfit = calculate_geoLineFit_angle_withRMS(x, y);											//writeln("t4 end");
			auto ch = calculate_geoLineFit_angle_raw_withSign(x,y);											// writeln(ch);
			double currentHeading = ch;																		// write("current heading is :");writeln(currentHeading);
			int[] currentLine = [dlast + 0, dlast + d-1];													// writeln(currentLine);
																											//writeln("checking RMS ERROR");
			double currentRMSError = lfit[1];
																											// write("heading change : ") ;
																											// writeln(abs(currentHeading - previousHeading));
																											// write("rmsError "); writeln(currentRMSError);
																											//// // readln;
																											//write("prev line was :");writeln(previousLine);
			if ( ( abs(currentHeading - previousHeading) <= this.maxDeviation_ofAngle*PI/180) && (currentRMSError <= this.maxRMSError) ){
				previousLine[1] = dlast + d-1;																// write("line is updated .."); writeln(previousLine);
				previousHeading = (previousHeading + currentHeading) / 2.0;
				d--;

			} else {
				this.allLines ~= previousLine.gdup;															// writeln("inserted new line ..."); writeln(this.allLines);
				previousLine = currentLine.gdup;
				previousHeading = currentHeading;
				allheadings ~= currentHeading;
				d --;


				/+
				for (int i = 0; i < this.allLines.length ; i ++) {											//writeln("drawing line : " ~ to!string(i));


					auto p0 = (*rd) [this.allLines[i][0]];
					auto p1 = (*rd) [this.allLines[i][1]];

					double y0;
					double y1;
					double y2;
					double x0;
					double x1;
					double x2;



					y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
					y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
					x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
					x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
					auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
					auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

					if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
					if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
				}

																											draw_map(); // // readln;
				+/


			}

			d = d + dlast;


		}																									//writeln("completed...");





		this.allLineHeadings = allheadings.gdup;

	}

	void add_turnLines() {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;									// writeln(this.allLines);

		for (int i = 0; i < this.allLines.length-1; i++) {													//writeln(this.allLines); // readln;writeln(i); writeln(this.allLines[i]);

			auto h0 = this.allLineHeadings[i];
			auto h1 = this.allLineHeadings[i+1];

			if( abs( h0-h1) > this.maxTurnThreshold) {

				auto d0 = calculate_lineLength(i);
				auto d1 = calculate_lineLength(i+1);

				if( d0 > this.minLineLength && d1 > this.minLineLength) {									// writeln(this.allLines[i]);
																											// writeln(this.allLines[i+1]);

					auto ld0 = this.allLines[i][1] - this.allLines[i][0];
					bool cut0 = false;

					if(ld0 > this.maxTurnLineLength ) {

						ld0 = ld0 - this.maxTurnLineLength;
						cut0 = true;
					}

					bool cut1 = false;
					auto ld1 = this.allLines[i+1][1] - this.allLines[i+1][0];								// writeln(ld1);

					if(ld1 > this.maxTurnLineLength ) {														// writeln("trimming ld1");

						ld1 = ld1 - this.maxTurnLineLength;													// write("max is: "); write(this.maxTurnLineLength);write("; after trim :"); writeln(ld1);
						cut1 = true;
					}
																											// writeln(ld1);
					if (cut0 && cut1) {																		// writeln("both cut");

						auto l0 = [this.allLines[i][0], this.allLines[i][0] + ld0];							// writeln(l0);
						auto l0c = [this.allLines[i][0] + ld0 , this.allLines[i+1][0] + ld1];				// writeln(l0c);
						auto l1 = [this.allLines[i+1][0] + ld1 , this.allLines[i+1][1]];					// writeln(l1);

						this.allLines[i] = l0;																// writeln(3);

						double[] x,y ;
						for (int ii = l0[0]; ii <= l0[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}																					//writeln("t3 end");writeln(x);writeln(y);
																											//writeln("t4");
						auto lfit = calculate_geoLineFit_angle_raw_withSign(x, y);							// writeln(4);

						this.allLineHeadings[i] = lfit;														// writeln(5);






						x.length = 0;
						y.length = 0;

						this.allLines[i+1] = l1;															// writ

						for (int ii = l1[0]; ii <= l1[1]; ii++) {

							x ~= (*rd)[ii].lon;																// writeln((*rd)[ii].lon);
							y ~= (*rd)[ii].lat;																// writeln((*rd)[ii].lat);			// x, y properly switched for lat & lon

						}
																											// print_highPrecisionArray(x); print_highPrecisionArray(y);
						lfit = calculate_geoLineFit_angle_raw_withSign(x, y);								// writeln(7);

						this.allLineHeadings[i+1] = lfit;													// writeln(8);

						this.allLines.insertInPlace(i+1, l0c);												// writeln(l0);write("-->"); writeln(l0c); writeln(l1); writeln(this.allLines[i+1]);

						x.length = 0;
						y.length = 0;

						for (int ii = l0c[0]; ii <= l0c[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}

						lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings.insertInPlace(i+1, lfit);										// writeln(10);

						i = i+1;																			// if the cut is in the middle, you know there is a fresh second line
																											// writeln(11);
																											// writeln(l0);
																											// writeln(l0c);
																											// writeln(l1);
																											// // readln;


						/+
						auto p0 = (*rd) [l0[0]];
						auto p1 = (*rd) [l0[1]];

						double y0;
						double y1;
						double y2;
						double x0;
						double x1;
						double x2;



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						p0 = (*rd) [l0c[0]];
						p1 = (*rd) [l0c[1]];



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						p0 = (*rd) [l1[0]];
						p1 = (*rd) [l1[1]];



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN2 = Color4f(120.00/255.00,250.00/255.00,250.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN2,to!int(x0),to!int(y0),to!int(x1),to!int(y1));

																											draw_map(); // readln;

						+/



					} else if( cut0 && ! cut1 ) {															// writeln("0 cut");


						auto l0 = [this.allLines[i][0], this.allLines[i][0] + ld0];
						auto l0c = [this.allLines[i][0] + ld0 , this.allLines[i+1][0] + ld1];

						this.allLines[i] = l0;
						double[] x,y ;
						for (int ii = l0[0]; ii <= l0[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}																					//writeln("t3 end");writeln(x);writeln(y);
																											//writeln("t4");
						auto lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings[i] = lfit;

						this.allLines[i+1] = l0c;

						x.length = 0;
						y.length = 0;

						this.allLines[i+1] = l0c;

						for (int ii = l0c[0]; ii <= l0c[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}

						lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings[i+1] =  lfit;
																											// writeln(l0);
																											// writeln(l0c);
																											// // readln;
						// i = i +1;																		// the cut is ahead of us, we do nothing
						/+
						auto p0 = (*rd) [l0[0]];
						auto p1 = (*rd) [l0[1]];

						double y0;
						double y1;
						double y2;
						double x0;
						double x1;
						double x2;



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(0,180.00/255.00,150.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						p0 = (*rd) [l0c[0]];
						p1 = (*rd) [l0c[1]];



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN1 = Color4f(180.00/255.00,150.00/255.00,70.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



																											draw_map(); // readln;
					    +/

					} else if( ! cut0 && cut1 ) {															// writeln("1 cut");

						auto l0c = [this.allLines[i][0], this.allLines[i+1][0] + ld1];
						auto l1 = [this.allLines[i+1][0] + ld1 , this.allLines[i+1][1]];

						this.allLines[i] = l0c;


						double[] x,y ;
						for (int ii = l0c[0]; ii <= l0c[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}																					//writeln("t3 end");writeln(x);writeln(y);
																											//writeln("t4");
						auto lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings[i] = lfit;



						this.allLines[i+1] = l1;


						x.length = 0;
						y.length = 0;

						this.allLines[i+1] = l1;

						for (int ii = l1[0]; ii <= l1[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}

						lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings[i+1] =  lfit;

						i = i+1;																			// the cut is at the i+1 position, so we move on to the next one

						/+
						auto p0 = (*rd) [l0c[0]];
						auto p1 = (*rd) [l0c[1]];

						double y0;
						double y1;
						double y2;
						double x0;
						double x1;
						double x2;



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(20.00/255.00,10.00/255.00,200.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						p0 = (*rd) [l1[0]];
						p1 = (*rd) [l1[1]];



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN1 = Color4f(200.00/255.00,10.00/255.00,10.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));

																											//write("cut length is :"); writeln(calculate_lineLength(i));
																											//draw_map(); // readln;

						+/
					} else if( !cut0 && ! cut1) {															// writeln("none cut");

						auto l0c = [this.allLines[i][0], this.allLines[i+1][1]];

						this.allLines[i] = l0c;
						this.allLines = this.allLines.remove(i+1);

						double[] x,y ;
						for (int ii = l0c[0]; ii <= l0c[1]; ii++) {

							x ~= (*rd)[ii].lon;
							y ~= (*rd)[ii].lat;																// x, y properly switched for lat & lon

						}																					//writeln("t3 end");writeln(x);writeln(y);
																											//writeln("t4");
						auto lfit = calculate_geoLineFit_angle_raw_withSign(x, y);

						this.allLineHeadings[i] = lfit;

						this.allLineHeadings = this.allLineHeadings.remove(i+1);

						i = i -1;

																											// writeln(l0c);
																											// // readln;

						/+
						auto p0 = (*rd) [l0c[0]];
						auto p1 = (*rd) [l0c[1]];

						double y0;
						double y1;
						double y2;
						double x0;
						double x1;
						double x2;



						y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
						auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

						if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
						if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));

																											draw_map(); // readln;
						+/

					}



				}

			}

		}

		for (int i = 0; i < this.allLines.length ; i ++) {													// writeln("drawing line : " ~ to!string(i));


			auto p0 = (*rd) [this.allLines[i][0]];
			auto p1 = (*rd) [this.allLines[i][1]];

			/+
			double y0;
			double y1;
			double y2;
			double x0;
			double x1;
			double x2;



			y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
			y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
			x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
			x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
			auto CYAN0 = Color4f(0,80.00/255.00,250.00/255.00);					//writeln(0);
			auto CYAN1 = Color4f(0,250.00/255.00,80.00/255.00);					//writeln(0);
			auto CYAN2 = Color4f(250.00/255.00,80.00/255.00,0);					//writeln(0);

			if (i % 3 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
			if (i % 3 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
			if (i % 3 == 2) drawLine_png(this.map,CYAN2,to!int(x0),to!int(y0),to!int(x1),to!int(y1));


																											// this is for ...… drawing the inner line segments in a single interpolated straight line
			/+
			for(int ij = this.allLines[i][0]; ij < this.allLines[i][1]; ij++) {

				auto pp1 = (*rd) [ij];
				auto pp2 = (*rd) [ij+1];

				y1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
				y2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
				x1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				x2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				auto VILT0 = Color4f(120.00/255.00,10.00/255.00,220.00/255.00);					//writeln(0);
				auto VILT1 = Color4f(220.00/255.00,10.00/255.00,120.00/255.00);					//writeln(0);
				if (ij % 2 == 0) drawLine_png(this.map,VILT0,to!int(x1),to!int(y1),to!int(x2),to!int(y2));
				if (ij % 2 == 1) drawLine_png(this.map,VILT1,to!int(x1),to!int(y1),to!int(x2),to!int(y2));

			}
			+/



			+/

			field.line l;

			auto l_length = calculate_lineLength(i);
			l.length = l_length;

			auto l_slp    = allLineHeadings[i];
			l.slope  = l_slp;

			l.uniqueID = i;

			l.startLat = p0.lat;
			l.startLon = p0.lon;

			l.endLat   = p1.lat;
			l.endLon   = p1.lon;

			l.startidx = this.allLines[i][0];
			l.endidx   = this.allLines[i][1];


			this.lineObjects ~= l;																			//writeln("added...");




		}																									// writeln("segments added ..");

	}

	void mark_allSweeps() {																					// now, go through ALL lines,
																											// check dictionary.
																											// and mark these line segments as such

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		int [] sweep	= new int[] (0);

		sweep ~= 0;
		auto ln0 = this.lineObjects[0];

        auto h0 = ln0.slope;																				// write(":::");writeln(h0);
        auto l0 = ln0.length;

		for( int i = 0; i <  this.lineObjects.length - 2; i++) {											// writeln(i);//writeln(this.lineObjects.length); writeln(i);




			auto ln1 = this.lineObjects[i+1];

			auto h1 = ln1.slope;																			// writeln(h1);writeln(h0);
			auto l1 = ln1.length;

			auto hp = this.lineObjects[i].slope;
			auto hn = this.lineObjects[i+2].slope;

			auto hChange = abs(h1-h0);																		// picked change in heading
																											// write("heading change :"); writeln(hChange );


			if(hChange <= this.maxTurnThreshold*PI/180 ) {

				if( l1 > this.maxTurnLineLength_inMeter) {
					sweep ~= i+1;
					h0 = h1;
				} else if ( abs (hn-h1) < this.maxTurnThreshold ) {
					sweep ~= i+1;
					h0 = h1;
				} else {


					if(sweep.length != 0) this.sweeps ~= sweep;
					sweep.length = 0;

					h0 = h1;
					l0 = l1;

					sweep ~= i+1;

					/+
					for (int ii = 0; ii < this.sweeps.length ; ii ++) {										writeln("drawing line : " ~ to!string(i));

						auto s = this.sweeps[ii];

						for (int j = 0; j < s.length; j++) {



							auto p0 = (*rd) [this.allLines[s[j]][0]];
							auto p1 = (*rd) [this.allLines[s[j]][1]];



							double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
							double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
							double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
							if (i % 2 == 1) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



							/+
																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
								auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
								auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

								if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
								if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
								if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}
							+/


						}



					}																						draw_map(); // readln;
					+/

				}

			}
			else {																							// writeln(sweep);

				//sweep ~= i;


				if(sweep.length != 0) this.sweeps ~= sweep;
				sweep.length = 0;

				h0 = h1;
				l0 = l1;
				i = i -1;

				/+
				for (int ii = 0; ii < this.sweeps.length ; ii ++) {											//writeln("drawing line : " ~ to!string(i));

					auto s = this.sweeps[ii];

					for (int j = 0; j < s.length; j++) {



						auto p0 = (*rd) [this.allLines[s[j]][0]];
						auto p1 = (*rd) [this.allLines[s[j]][1]];



						double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
						drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



						/+
																													// this is for ...… drawing the inner line segments in a single interpolated straight line
						for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

							auto pp1 = (*rd) [ij];
							auto pp2 = (*rd) [ij+1];

							double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
							double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
							double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
							auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
							auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

							if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

						}
						+/


					}



				}																							draw_map(); // readln;
				+/

			}


		}


		/+
		for (int i = 0; i < this.sweeps.length ; i ++) {													//writeln("drawing line : " ~ to!string(i));

			auto s = this.sweeps[i];

			for (int j = 0; j < s.length; j++) {



				auto p0 = (*rd) [this.allLines[s[j]][0]];
				auto p1 = (*rd) [this.allLines[s[j]][1]];



				double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
				double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
				double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
				auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

				if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
				if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



				/+
																											// this is for ...… drawing the inner line segments in a single interpolated straight line
				for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

					auto pp1 = (*rd) [ij];
					auto pp2 = (*rd) [ij+1];

					double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
					double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
					double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
					double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
					auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
					auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
					auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

					if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
					if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
					if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

				}
				+/


			}



		}
		+/










	}

	void get_fieldSweeps() {

    	field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		//int[] hooklist ;

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;


		this.maxLineDist = this.workWidth * 2 / 100.00 ;													// writeln(this.maxLineDist); readln();


		int [] markedSweeps = new int [] (0);

		for (int i = 1; i < this.sweeps.length-1; i++) {													write("with sweep :"); writeln(i);

			if (canFind(markedSweeps, i)) continue;

			double sweepLength_i = calculate_sweepLength(i);
			if (sweepLength_i < this.minLineLength) {														// writeln("probably hook");


			}

			int [] guessedField = new int[] (0);
			guessedField ~= i;

			//int []


			search_fromBeginning: while(true) {


				for (int j = 1; j < this.sweeps.length-1; j++) {

						if ( i == j ) continue;
						if (canFind(markedSweeps, j)) continue;												write("checking sweep : "); writeln(j); writeln(this.sweeps[j]);




						// update_map();

						/+
						auto gfield = guessedField;

						for (int ii = 0; ii < gfield.length ; ii ++) {

							auto s = this.sweeps[gfield[ii]];												// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int jj = 0; jj < s.length; jj++) {



								auto p0 = (*rd) [this.allLines[s[jj]][0]];
								auto p1 = (*rd) [this.allLines[s[jj]][1]];



								double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
								double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
								double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));


								/+
																												// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
									auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
									auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

									if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



								}

								+/



							}
						}

						auto s = this.sweeps[j];															// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int jj = 0; jj < s.length; jj++) {



							auto p0 = (*rd) [this.allLines[s[jj]][0]];
							auto p1 = (*rd) [this.allLines[s[jj]][1]];



							double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
							double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
							double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							auto VILT0 = Color4f(200.00/255.00,10.00/255.00,200.00/255.00);							//writeln(0);
							drawLine_png(this.map,VILT0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



							/+
																											// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(20.00/255.00,10.00/255.00,200.00/255.00);							//writeln(0);
								auto VILT1 = Color4f(150.00/255.00,20.00/255.00,120.00/255.00);							//writeln(0);
								auto VILT2 = Color4f(200.00/255.00,20.00/255.00,150.00/255.00);							//writeln(0);

								if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
								else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
								else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



							}
							+/



						}

						+/






						bool abreast = false;
						int kk;																				writeln("checiking abreast condition ...");
						for (int k = 0; k < guessedField.length; k++){										write("against :"); writeln(guessedField[k]);
							double abreastRatio = calculate_sweepAbreastRatio(guessedField[k],j);			//write("checking abreast ratio with :") ;
																											write("abreast ratio found: ");writeln(abreastRatio);// readln;
							if (abreastRatio > this.minOverlap) {
								abreast = true;
								kk = k;
								break;
							}
						}																					// writeln("checiking abreast condition finished ...");
																											// writeln("check abreast ");
						if ( ! abreast) continue;															write("abreast match : ");writeln(guessedField[kk]); draw_map();// readln;

						double pickD;
						bool closeBy = false;																writeln("checiking closeby condition ...");
						for (int k = 0; k < guessedField.length; k++){										// write(" distance check against :"); writeln(guessedField[k]);writeln(maxLineDist);
							double sweepDist = calculate_avgSweepDist_pairwise ([guessedField[k],j]);		// pickD = sweepDist; write("sweep to sweep distance found : "); writeln(sweepDist);
																											// write(" max dist is ; ") ; writeln(this.maxLineDist);
							if ( sweepDist < this.maxLineDist && sweepDist > 0) {							// for a NON abreat distance measure, we return -1,
																											// because, a paor of lineshighly skewed can still appear abreast.
																											// so it has to be > 0,
																											// otherwise -1 will always fullfil the ( sweepdist < threshold ) condition
								closeBy = true;																writeln(sweepDist); writeln("passed"); //// readln;
								break;
							}
						}
																											// writeln("checiking closeby condition finished...");
																											// write("distances are :");writeln(pickD); draw_map() ; readln();
						if(! closeBy) continue;																writeln("pass"); // readln();

						bool possiblyHook = false;
																											writeln("checiking hook condition ...");
						double sweepLength_j = calculate_sweepLength(j);									// writeln(this.sweeps[j]); writeln(sweepLength_j) ;// // readln;
						if (sweepLength_j < this.maxTurnLineLength_inMeter) {								// writeln("probably hook"); // readln;

								auto hp =  calculate_sweepHeading( j-1);
								auto h  =  calculate_sweepHeading( j);
								auto hn =  calculate_sweepHeading( j+1);									// writeln(this.sweeps[j]);writeln(abs(hp-h) * 180/PI);writeln(abs(h-hn) * 180/PI); // // readln;

								if( abs(hp-h) > this.maxTurnThreshold*PI/180.00 || abs(h-hn) > this.maxTurnThreshold*PI/180.00) {
									possiblyHook = true;													//write("is hook: "); writeln(this.sweeps[j]) ;// readln;


									/+
									auto s = this.sweeps[j];													// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

									for (int jj = 0; jj < s.length; jj++) {



										auto p0 = (*rd) [this.allLines[s[jj]][0]];
										auto p1 = (*rd) [this.allLines[s[jj]][1]];


										/+
										double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
										double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
										double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
										auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

										if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
										if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
										+/



																														// this is for ...… drawing the inner line segments in a single interpolated straight line
										for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

											auto pp1 = (*rd) [ij];
											auto pp2 = (*rd) [ij+1];

											double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
											double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
											double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
											double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
											auto VILT0 = Color4f(250.00/255.00,50.00/255.00,20.00/255.00);							//writeln(0);
											drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

										}



									}																				//draw_map(); //// readln;
									//hooklist ~= j;
									+/
								}

						}
																											writeln("checiking hook condition finished...");
						if(possiblyHook) continue;

						bool parallel  = true;																writeln("testing parallel");
						for (int k = 0; k < guessedField.length; k++){										// write("checking if parallel :"); writeln(guessedField[k]);
							if (!check_sweepParallel(guessedField[k],j)) {									// writeln("parallel failed");
								parallel = false;
								break;
							}																				// writeln("not parallel");
						}																					// writeln("testing parallel finished ...");

						if ( parallel ) {																	writeln("parallel");

																											/+
																											if (j == 14) {



							update_map();

							/+
							auto gfield = guessedField;

							for (int ii = 0; ii < gfield.length ; ii ++) {

								auto s = this.sweeps[gfield[ii]];												// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

								for (int jj = 0; jj < s.length; jj++) {



									auto p0 = (*rd) [this.allLines[s[jj]][0]];
									auto p1 = (*rd) [this.allLines[s[jj]][1]];



									double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
									double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
									double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
									drawLine_png(this.map,VILT0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));


									/+
																													// this is for ...… drawing the inner line segments in a single interpolated straight line
									for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

										auto pp1 = (*rd) [ij];
										auto pp2 = (*rd) [ij+1];

										double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
										double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
										double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
										auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
										auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

										if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



									}

									+/



								}
							}
							+/

							auto s_ = this.sweeps[14];															// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int jj = 0; jj < s_.length; jj++) {



								auto p0 = (*rd) [this.allLines[s_[jj]][0]];
								auto p1 = (*rd) [this.allLines[s_[jj]][1]];



								double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
								double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
								double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(200.00/255.00,10.00/255.00,200.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



								/+
																												// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto VILT0 = Color4f(20.00/255.00,10.00/255.00,200.00/255.00);							//writeln(0);
									auto VILT1 = Color4f(150.00/255.00,20.00/255.00,120.00/255.00);							//writeln(0);
									auto VILT2 = Color4f(200.00/255.00,20.00/255.00,150.00/255.00);							//writeln(0);

									if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



								}
								+/



							}

							s_ = this.sweeps[144];															// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int jj = 0; jj < s_.length; jj++) {



								auto p0 = (*rd) [this.allLines[s_[jj]][0]];
								auto p1 = (*rd) [this.allLines[s_[jj]][1]];



								double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
								double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
								double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(20.00/255.00,200.00/255.00,200.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



								/+
																												// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[jj]][0]; ij < this.allLines[s[jj]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto VILT0 = Color4f(20.00/255.00,10.00/255.00,200.00/255.00);							//writeln(0);
									auto VILT1 = Color4f(150.00/255.00,20.00/255.00,120.00/255.00);							//writeln(0);
									auto VILT2 = Color4f(200.00/255.00,20.00/255.00,150.00/255.00);							//writeln(0);

									if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
									else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



								}
								+/



							}



																												draw_map();


																												// readln;

																											}
																											+/
							guessedField ~= j;
							markedSweeps ~= j;																// write("field added ");writeln(guessedField);
							continue search_fromBeginning;

						}																					// writeln("not parallel "); writeln("will break");

																											writeln("all complete");

				}



				break;
			}																								//writeln("will now search for new field");
																											//write("picked field");writeln(guessedField);


			if(guessedField.length > 2) {																	write("parallel field found :" ); writeln(guessedField);



				// update_map();

				/+
				auto gfield = guessedField;

				for (int ii = 0; ii < gfield.length ; ii ++) {												// writeln("drawing line : " ~ to!string(i));
																											// write("direction was :"); writeln(calculate_sweepHeading(guessedField[ii]) * 180/PI	);

					auto s = this.sweeps[gfield[ii]];														// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

					for (int j = 0; j < s.length; j++) {



						auto p0 = (*rd) [this.allLines[s[j]][0]];
						auto p1 = (*rd) [this.allLines[s[j]][1]];



						double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
						double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
						double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
						auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
						auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
						auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

						if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
						else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
						else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2))



						/+
																										// this is for ...… drawing the inner line segments in a single interpolated straight line
						for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

							auto pp1 = (*rd) [ij];
							auto pp2 = (*rd) [ij+1];

							double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
							double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
							double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
							auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
							auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
							auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

							if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
							else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



						}
						+/




					}



				}																							draw_map(); // readln;

				+/




																											writeln("testing max field dist ...");
				double fWidth = calculate_maxSweepDist(guessedField);										// maximum sweep to sweep distance is field width,
																											// this distance is measured among abreast lines in all the sweeps, taken pairwise
				if( fWidth < this.maxRoadWidth ) {
					// not a field.
					// NOP
				} else {

					if (guessedField.length > 3) {
						markedSweeps ~= guessedField.gdup;
						this.baseFields ~= guessedField.gdup;												write("check this field"); writeln(guessedField);// // readln;


					}

				}

			}
		}


																											//hooklist.length -= hooklist.uniq().copy(hooklist).length;
																											//for(int i = 0; i < hooklist.length; i++) writeln(hooklist[i]);
	}


	/////////////////////////////////////////////////////////////////////////////



private :

	short dataType_current;
	int drawH, drawW;
	int convexHullLength;
	int[] semiMajorAxis;
	int[] semiMinorAxis;
	
	double latdiff_global;
	double londiff_global;
	
	double latMax_global;
	double latMin_global;
	double lonMax_global;
	double lonMin_global;
	double multiplier_global;

	uint width_global;
	uint height_global;
	
	int transport_startEpicenter;
	int transport_endEpicenter;
	int xGressCount;
	
	neuron.edgeDetectorNeuron[] edgeDetectors ;


	field.rawData [] rd_raw;

	field.line [] lineObjects    = new field.line[] (0);
	field.line [] segmentObjects = new field.line[] (0);

	int [][] sweeps 		= new int[][] (0,0);
	int [] possibleHooks 	= new int[] (0);
	int [][] possibleTracks = new int[][] (0,0);
	
	double[] allLineHeadings= new double [] (0);
	
	int [][] baseFields = new int[][] (0,0);
	int [][] baseFields_copy = new int[][] (0,0);

	sweep_withScore[] allSweepObjects;

	int [][] turnLines = new int[][] (0,0);
	int [][] crossLines = new int[][] (0,0);


	int [][] plainFields= new int[][] (0,0);
	int [][] fieldBoundaries = new int [][] (0,0);
	double [][][] fieldBoundariesRaw = new double [][][] (0,0,0);
	double [][] emergency = new double  [][] (0,0);
	int [] allRedLines = new int[] (0);
	int [][] redFieldLines = new int[][] (0,0);

	int [][] red_greenFields = new int[][] (0,0);
	
	int [] ingressPoints = new int[](0);
	int [] outgressPoints = new int[](0);
	
	
	double[][][] innerTriangles = new double [][][] (0,0,0);
	int [] candidatePoints = new int [] (0);
	int[][] bestFieldLines = new int [][] (0,0);
	int [] fieldIndices = new int [] (0);
	int [][] allLines = new int [][] (0,0);
	int [] goodlines = new int [] (0);
	int [][][] fieldCorrections = new int [][][] (0,0,0);
	
	int[][] knotPointIndices = new int [][] (0,0);
	int mostLikelyLocation_ofFarm = -1;
	int [] mergedLocation_ofFarm = new int[] (0);
	double [] farmCenter = new double [] (0);
	int firstLoadingPoint = -1;
	
	int [][] skiplines = new int[][] (0,0);
	int [] notRedLinesGlobal = new int [](0);
	
	auto map = new Image!(IntegerPixelFormat.RGB8)(1,1)  ;
	auto mapCopy =  new Image!(IntegerPixelFormat.RGB8)(1,1)  ;
	auto convexHullDiagonals_ofMap = new int[][] (0,0);
	
	
	double fieldSizeNormalizer = 8192;
	
	
	string jsonstr;
	
	int[][] estimatedFields;
	int [][] greenLimits = new int [][] (0,0);


	class waypoint {

		double lat;
		double lon;

		this() {
			lat = 0;
			lon = 0;
		}
		~this() {}

	}

	class checkResult {

		bool success;
		int  target ;

		this() {

			success = false;
			target  = -1;

		}
		~this(){};



	}

	class checkResult_crossLine : checkResult {

		int[] lineTerminals = new int[] (0);
		double ratio = -1;

		double distanceToField ;

	}

	class trendAnalysisResult {

		double actualTrend;
		segment [] segments;

		bool success;
		bool tentativeNewTrend;

	}

	class segment {

		int id;
		bool outlier;

		this(){}
		~this(){}

	}

	class sweep_withScore {


		int sweepID;

		int current_parentField;


		double current_parallelScore;
		double current_crossLineScore;
		double current_turnLineScore;

		int [] possible_parentField;


		double[] possible_parallelScore;
		double[] possible_crossLineScore;
		double[] possible_turnLineScore;

		this(){}
		~this(){}


	}

	class field_withScore {

		double [int] originalLineScores ;
		int[] lines = new int[] (0);																		// line here actually means sweep

		int[] remaining_parallelLines = new int[] (0);

		double [int][] crossLineScores	  ;																	// we need to keep track of multiple scores...
		int[] added_crossLines		  = new int[] (0);

		int[] crossLineIntercepts	  = new int[] (0);
		double[] crossLineIntercepts_width	  = new double[] (0);

		double [int][] turnLineScores	;
		int[] added_turnLines		  = new int[] (0);

		double [int] transferLineScores ;
		int[] added_transferLines	  = new int[] (0);

		this(){}
		~this(){}

	}

	struct crossLineResult {

		int target;
		double value;

	}

	struct turnLineResult {

		int target;
		double value;

	}




	double [] calculate_geoPoint_atDistance_andAngle(field.rawData p0, double d, field.rawData p1) {

        double[] tlp0 = new double[] (0);
		tlp0 =  [p0.lat, p0.lon];

		double[] tlp1 = new double[] (0);
		tlp1 =  [p1.lat, p1.lon];


		double[] u = [tlp1[1] - tlp0[1], tlp1[0] - tlp0[0]];						// u flipped lat and lon

		u[] /= sqrt ( (u[0] * u[0]) + u[1] * u[1]);
		u[] *= d / 150000;

		return [tlp0[1] + u[0] , tlp0[0] + u[1]];								// so we add with flipped lat and lon
	}

	double calculate_lineLength( int i) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		auto l = this.allLines[i];
		auto p0 = (*rd)[l[0]];
		auto p1 = (*rd)[l[1]];

		return calculate_geoDistance_vincenty(p0.lat,p1.lat, p0.lon, p1.lon);

	}

	double calculate_sweepLength(int i) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];
		double dst = 0;
		foreach(li; si)	dst += calculate_lineLength(li);

		return dst;
	}

	double calculate_sweepLength_pointtoPoint(int i) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];
		double dst = 0;

		auto p0 = (*rd)[this.allLines[si[0]][0]];
		auto p1 = (*rd)[this.allLines[si[$-1]][1]];

		dst = calculate_geoDistance_vincenty(p0.lat, p1.lat, p0.lon, p1.lon);

		return dst;
	}

	double calculate_sweepDistance( int i, int j) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];
		auto sj = this.sweeps[j];

		if (si.length < sj.length) {}
		else {
			swap(i,j);																					// take the smaller one
			swap(si, sj);
		}
		double [] dsts = new double[] (0);
		for( int li = 0; li < si.length; li++){															//write("checking sweep "); write(i); write("against");writeln(j);writeln(si[li]);

			auto d = calculate_linetoSweepDistance_abreast(si[li],j);
			if (d != -1) dsts ~= d;

		}



																										// writeln(dsts);
		double r;
		if(dsts.length != 0) r = find_jenksMean(dsts);
		else r = -1;
		return r;




	}

	double calculate_sweepDistance_minimal( int i, int j) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];
		auto sj = this.sweeps[j];


		auto pi0 = this.allLines[si[0]][0];
		auto pi1 = this.allLines[si[$-1]][1];
		auto pj0 = this.allLines[sj[0]][0];
		auto pj1 = this.allLines[sj[$-1]][1];

		auto d0 = calculate_geoDistance_vincenty( (*rd)[pi0].lat, (*rd)[pj0].lat, (*rd)[pi0].lon, (*rd)[pj0].lon);		// writeln(d0);
		auto d1 = calculate_geoDistance_vincenty( (*rd)[pi0].lat, (*rd)[pj1].lat, (*rd)[pi0].lon, (*rd)[pj1].lon);		// writeln(d1);
		auto d2 = calculate_geoDistance_vincenty( (*rd)[pi1].lat, (*rd)[pj0].lat, (*rd)[pi1].lon, (*rd)[pj0].lon);		// writeln(d2);
		auto d3 = calculate_geoDistance_vincenty( (*rd)[pi1].lat, (*rd)[pj1].lat, (*rd)[pi1].lon, (*rd)[pj1].lon);		// writeln(d3);


		return min(d0,d1,d2,d3);




	}

	double calculate_sweepAbreastRatio (int i, int j) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si_l0 = this.sweeps[i][0];																		write("1: ");writeln(si_l0);
		auto si_l1 = this.sweeps[i][$-1];																	write("2: ");writeln(si_l1);
		auto sj_l0 = this.sweeps[j][0];																		write("3: ");writeln(sj_l0);
		auto sj_l1 = this.sweeps[j][$-1];																	write("4: ");writeln(sj_l1);

		auto l00 = this.allLines[si_l0];																	write("5: ");writeln(l00);
		auto l01 = this.allLines[si_l1];																	write("6: ");writeln(l01); writeln(this.allLines.length); writeln(sj_l0); writeln(this.allLines[sj_l0]);
		auto l10 = this.allLines[sj_l0];																	write("7: ");writeln(l10);
		auto l11 = this.allLines[sj_l1];																	write("8: ");writeln(l11);


		auto p0 = l00[0];																					write("9: ");writeln(p0);
		auto p1 = l01[1];																					write("10: ");writeln(p1);
		auto q0 = l10[0];																					write("11: ");writeln(q0);
		auto q1 = l11[1];																					write("12: ");writeln(q1);writeln("all OK");


		return calculate_abreastRatio((*rd)[p0],(*rd)[p1],(*rd)[q0],(*rd)[q1]);

	}

	double calculate_sweepHeading (int i) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];




		auto l0 = this.allLines[si[0]];

		auto p0 = l0[0];
		auto p1 = l0[1];

		auto h0 = calculate_geoLineFit_angle_raw([ (*rd)[p0].lon, (*rd)[p1].lon ],[ (*rd)[p0].lat, (*rd)[p1].lat  ]);

		return h0;



	}

	double calculate_sweepHeading_withSign (int i) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];




		auto l0 = this.allLines[si[0]];

		auto p0 = l0[0];
		auto p1 = l0[1];

		auto h0 = calculate_geoLineFit_angle_raw_withSign([ (*rd)[p0].lon, (*rd)[p1].lon ],[ (*rd)[p0].lat, (*rd)[p1].lat  ]);

		return h0;



	}

	bool check_sweepParallel (int i, int j) {


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto si = this.sweeps[i];
		auto sj = this.sweeps[j];

		if (si.length < sj.length) {}
		else {
			swap(i,j);																					// take the smaller one
			swap(si, sj);
		}																					// take the smaller one


		bool r = false;



		auto l0 = this.allLines[si[0]];
		auto l1 = this.allLines[sj[$-1]];

		auto p0 = l0[0];
		auto p1 = l0[1];
		auto q0 = l1[0];
		auto q1 = l1[1];

		auto h0 = calculate_geoLineFit_angle_raw([ (*rd)[p0].lon, (*rd)[p1].lon ],[ (*rd)[p0].lat, (*rd)[p1].lat  ]);
		auto h1 = calculate_geoLineFit_angle_raw([ (*rd)[q0].lon, (*rd)[q1].lon ],[ (*rd)[q0].lat, (*rd)[q1].lat  ]);
																											//write("for sweep :"); write(i); write( " heading is: "); writeln(h0*180/PI);
																											//write("for sweep :"); write(j); write( " heading is: "); writeln(h1*180/PI);
																											//writeln(this.maxParallelOffset);

		if ( abs (h0-h1) < this.maxParallelOffset_fld*PI/180) r = true;
// 																											if(r) {
//
// 																												write("checking sweeps: ") ; writeln([i,j]);
// 																												writeln(h0*180/PI); writeln(h1*180/PI); writeln(abs(h0-h1)*180/PI);
// 																												// // readln;
// 																											}

		return r;



	}

	bool check_sweepIntersect (int i, int j) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		auto s_inFld  = this.sweeps[i];
		auto s_underTest = this.sweeps[j];

		auto si = s_inFld;
		auto sj = s_underTest;

		bool r = false;

		checkloop : for( int ii = 0; ii < si.length; ii++) {

			for (int jj = 0; jj < sj.length; jj++) {

				auto li = si[ii];
				auto lj = sj[jj];

				auto p0 = this.allLines[li][0];
				auto p1 = this.allLines[li][1];
				auto q0 = this.allLines[lj][0];
				auto q1 = this.allLines[lj][1];

				auto d0 = [ [ (*rd)[p0].lon, (*rd)[p0].lat] , [ (*rd)[p1].lon, (*rd)[p1].lat]];
				auto d1 = [ [ (*rd)[q0].lon, (*rd)[q0].lat] , [ (*rd)[q1].lon, (*rd)[q1].lat]];

				/+
																											if(canFind(this.baseFields[0], si)) {
																												if (j == 293 || j == 298  ) {
																													writeln(i); writeln(j);
																													print_highPrecisionArray(d0[0]);
																													print_highPrecisionArray(d0[1]);
																													print_highPrecisionArray(d1[0]);
																													print_highPrecisionArray(d1[1]);



						for (int kk = 0; kk < si.length; kk++) {

							for(int ij = this.allLines[si[kk]][0]; ij < this.allLines[si[kk]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto GREEN = Color4f(2.00/255.00,250.00/255.00,0.00/255.00);							//writeln(0);
								drawLine_png(this.map,GREEN,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}



						for (int kk = 0; kk < sj.length; kk++) {
							for(int ij = this.allLines[sj[kk]][0]; ij < this.allLines[sj[kk]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto BLU = Color4f(20.00/255.00,10.00/255.00,220.00/255.00);							//writeln(0);
								drawLine_png(this.map,BLU,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}




																													draw_map();
																													// // readln;
																												}
																											}

				+/


				if (check_intersect_withinLines ( d0,d1)) {													//writeln("intercept occured.");

					r = true;
					break checkloop;

				}


			}

		}

		if ( !r) {


			auto fp = (*rd)[this.allLines[s_inFld[0]][0]];
			auto lp = (*rd)[this.allLines[s_inFld[$-1]][1]];

			double d = -1;

			for(int ii = 0; ii < s_underTest.length; ii++) {

				auto l = this.allLines[s_underTest[ ii]];

				auto l0 = (*rd)[l[0]];
				auto l1 = (*rd)[l[1]];


				auto w_curr_f = drop_geoNormal(fp, l0, l1);
				auto w_curr_l = drop_geoNormal(lp, l0, l1);

				auto df = calculate_geoDistance_vincenty(w_curr_f.lat, fp.lat, w_curr_f.lon, fp.lon);
				auto dl = calculate_geoDistance_vincenty(w_curr_l.lat, lp.lat, w_curr_l.lon, lp.lon);

				if ( d == -1) d = min(df, dl);
				else if ( min(df,dl) < d) d = min(df, dl);
			}

			if ( d < this.crad) r = true;
		}


		return r;


	}
	
	double calculate_linetoLineDistance( int i, int j) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		auto l0 = this.allLines[i];
		auto l1 = this.allLines[j];


		double a =  calculate_geoDistance_vincenty((*rd)[l0[0]].lat, (*rd)[l1[0]].lat, (*rd)[l0[0]].lon, (*rd)[l1[0]].lon);
		double b =  calculate_geoDistance_vincenty((*rd)[l0[0]].lat, (*rd)[l1[1]].lat, (*rd)[l0[0]].lon, (*rd)[l1[1]].lon);
		double c =  calculate_geoDistance_vincenty((*rd)[l0[1]].lat, (*rd)[l1[0]].lat, (*rd)[l0[1]].lon, (*rd)[l1[0]].lon);
		double d =  calculate_geoDistance_vincenty((*rd)[l0[1]].lat, (*rd)[l1[1]].lat, (*rd)[l0[1]].lon, (*rd)[l1[1]].lon);

		return (a + b + c + d) / 4.0;

	}
	
	double calculate_linetoSweepDistance_pointwise( int li, int sj){ 										//write("checking sweep SEGMENT "); write(li); write("against");writeln(sj);

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;
																											// update_map();
		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		auto ln = this.allLines[li];
		auto sp = this.sweeps[sj];

		auto testSweep = sp;

		/+
		for (int j = 0; j < testSweep.length; j++) {

			auto p0 = (*rd) [this.allLines[testSweep[j]][0]];
			auto p1 = (*rd) [this.allLines[testSweep[j]][1]];


			/+
			double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
			double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
			double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
			double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
			auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
			auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

			if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
			if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
			+/



																					// this is for ...… drawing the inner line segments in a single interpolated straight line
			for(int ij = this.allLines[testSweep[j]][0]; ij < this.allLines[testSweep[j]][1]; ij++) {

				auto pp1 = (*rd) [ij];
				auto pp2 = (*rd) [ij+1];

				double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
				double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
				double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				auto RED = Color4f(220.00/255.00,10.00/255.00,220.00/255.00);							//writeln(0);
				drawLine_png(this.map,RED,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

			}


			for(int ij =ln[0]; ij < ln[1]; ij++) {

				auto pp1 = (*rd) [ij];
				auto pp2 = (*rd) [ij+1];

				double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
				double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
				double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
				auto RED = Color4f(20.00/255.00,10.00/255.00,220.00/255.00);							//writeln(0);
				drawLine_png(this.map,RED,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

			}



		}
		+/




		double [] dst0 = new double [] (0);
		double [] dst1 = new double [] (0);

		for(int lj = 0; lj < sp.length; lj ++) {															//write("checking second sweep segment ");writeln(lj);

			auto p0 = (*rd)[ln[0]];
			auto p1 = (*rd)[ln[1]];

			auto q0 = (*rd)[ this.allLines [sp[lj] ] [0]];
			auto q1 = (*rd)[ this.allLines [sp[lj] ] [1]];

			auto w0 = calculate_geoDistance_vincenty(q0.lat,p0.lat, q0.lon, p0.lon);
			auto w1 = calculate_geoDistance_vincenty(q0.lat,p1.lat, q0.lon, p1.lon);
			auto w2 = calculate_geoDistance_vincenty(q1.lat,p0.lat, q1.lon, p0.lon);
			auto w3 = calculate_geoDistance_vincenty(q1.lat,p1.lat, q1.lon, p1.lon);
																											//write("cross track dist is :");writeln(w);

			dst0 ~= w0;
			dst0 ~= w2;
			dst1 ~= w1;
			dst1 ~= w3;


		}																									//draw_map(); writeln(dst); // // readln;

		auto r = max(dst0.minElement, dst1.minElement);														// write("distance to target field : " ); writeln(r);
		return r;



	}

	double calculate_linetoSweepDistance( int li, int sj) {													//write("checking sweep SEGMENT "); write(li); write("against");writeln(sj);

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto ln = this.allLines[li];
		auto sp = this.sweeps[sj];

		auto midPoint = [ ((*rd)[ln[0]].lat +  (*rd)[ln[1]].lat) / 2.0 ,  ((*rd)[ln[0]].lon +  (*rd)[ln[1]].lon) / 2.0  ];
																											//write("line mid point = ");print_highPrecisionArray(midPoint);

		double [] dst = new double [] (0);

		for(int lj = 0; lj < sp.length; lj ++) {															//write("checking second sweep segment ");writeln(lj);

			auto p0 = (*rd)[ln[0]];
			auto p1 = (*rd)[ln[1]];

			auto q0 = (*rd)[ this.allLines [sp[lj] ] [0]];
			auto q1 = (*rd)[ this.allLines [sp[lj] ] [1]];

			auto abr = calculate_abreastRatio(p0,p1,q0,q1);

			if ( abr < this.minOverlap) continue;															//writeln(abr);
																											//print_highPrecisionArray([(q0.lat + q1.lat)/2, midPoint[0], (q0.lon+q1.lon)/2, midPoint[1]]);
			auto w = calculate_geoCrossTrackdistance(q0.lat, q1.lat, midPoint[0], q0.lon, q1.lon, midPoint[1]);
																											//write("cross track dist is :");writeln(w);

			dst ~= w;

		}																									//writeln(dst);

		if(dst.length == 0) {

			auto midPointS = [ ((*rd)[ this.allLines [sp[0] ] [0] ].lat +  (*rd)[ this.allLines [sp[$-1] ] [1] ].lat) / 2.0 ,  ((*rd)[ this.allLines [sp[0] ] [0] ].lon +  (*rd)[ this.allLines [sp[$-1] ] [1] ].lon) / 2.0  ];
			dst ~= calculate_geoDistance(midPoint[0], midPointS[0], midPoint[1], midPointS[1]);

		}

		return mean(dst);



	}

	double calculate_linetoSweepDistance_abreast( int li, int sj) {											//write("checking sweep SEGMENT "); write(li); write("against");writeln(sj);

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		auto ln = this.allLines[li];																		//writeln(sj); writeln(this.sweeps.length);
		auto sp = this.sweeps[sj];

		auto midPoint = [ ((*rd)[ln[0]].lat +  (*rd)[ln[1]].lat) / 2.0 ,  ((*rd)[ln[0]].lon +  (*rd)[ln[1]].lon) / 2.0  ];
																											//write("line mid point = ");print_highPrecisionArray(midPoint);

		double [] dst = new double [] (0);

		for(int lj = 0; lj < sp.length; lj ++) {															//write("checking second sweep segment ");writeln(lj);

			auto p0 = (*rd)[ln[0]];
			auto p1 = (*rd)[ln[1]];

			auto q0 = (*rd)[ this.allLines [sp[lj] ] [0]];
			auto q1 = (*rd)[ this.allLines [sp[lj] ] [1]];

			auto abr = calculate_abreastRatio(p0,p1,q0,q1);

			if ( abr < this.minOverlap) continue;															//writeln(abr);
																											//print_highPrecisionArray([(q0.lat + q1.lat)/2, midPoint[0], (q0.lon+q1.lon)/2, midPoint[1]]);
			auto w = drop_geoNormal_pointToline(midPoint, q0, q1);
			auto a = calculate_geoDistance_vincenty(w.lat, midPoint[0], w.lon, midPoint[1]);
																											// write("cross track dist is :"); writeln(a);

			dst ~= a;

		}																									//writeln(dst);

		if(dst.length == 0) {

			dst ~= -1;

		}

		return mean(dst);



	}

	double calculate_abreastRatio( field.rawData p1, field.rawData p2, field.rawData q1, field.rawData q2) {

		auto s_ids = [p1.id, p2.id, q1.id, q2.id];
		auto s = sort_endPoints(p1, p2, q1, q2);								//writeln(s); writeln(s_ids);

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;


		double r = 0;




		auto s00 = (*rd)[ s_ids[s[0]] ];
		auto s01 = (*rd)[ s_ids[s[3]] ];


		auto d1 = calculate_geoDistance_vincenty ( s00.lat, s01.lat, s00.lon, s01.lon);

		auto s10 = (*rd)[ s_ids[s[1]] ];
		auto s11 = (*rd)[ s_ids[s[2]] ];


		auto d2 = calculate_geoDistance_vincenty ( s10.lat, s11.lat, s10.lon, s11.lon);



		/+
		double y1 = to!int(this.multiplier_global * (this.latMax_global - s10.lat) + offsetX);
		double y2 = to!int(this.multiplier_global * (this.latMax_global - s11.lat) + offsetX);
		double x1 = to!int((this.multiplier_global * (s10.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
		double x2 = to!int((this.multiplier_global * (s11.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
		auto GREEN1 = Color4f(250.00/255.00,250.00/255.00,20.00/255.00);	//writeln(0);





		double ay1 = to!int(this.multiplier_global * (this.latMax_global - s00.lat) + offsetX);
		double ay2 = to!int(this.multiplier_global * (this.latMax_global - s01.lat) + offsetX);
		double ax1 = to!int((this.multiplier_global * (s00.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
		double ax2 = to!int((this.multiplier_global * (s01.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
		auto GREEN2 = Color4f(150.00/255.00,150.00/255.00,20.00/255.00);

		drawLine_png(this.map,GREEN1,to!int(x1),to!int(y1),to!int(x2),to!int(y2));
		drawLine_png(this.map,GREEN2,to!int(ax1),to!int(ay1),to!int(ax2),to!int(ay2));



		draw_map(); // readln;
		+/

		if ( std.math.abs( s[0] - s[1] ) == 1 && std.math.abs( s[2] - s[3] ) == 1 ) {
			r = -1;
		}
		else {																	// check if the overcome is smalllllll

			if( ( ( s[0] == 0 && s[3] == 1 ) || ( s[0] == 1 && s[3] == 0 ) )
			 || ( ( s[0] == 2 && s[3] == 3 ) || ( s[0] == 3 && s[3] == 2 ) ) )
				r = 1; // this will occur if j is completely covered by i, normally abreast, no need to make a false...
			else {																// now we are checking if there is a very narrow slit
				r = d2 / d1 ;													// overlap too small

			}

		}

		return r;




	}
	
	short[] sort_endPoints(field.rawData p0, field.rawData p1, field.rawData q0, field.rawData q1) {

		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;

		double u0 = 0;															// length of vector 0 --> 0
		double u1 = 1; 															// length of vector 1 --> 0


		auto n  = [ ( p1.lat - p0.lat) ,  ( p1.lon - p0.lon) ];

		auto w2 = drop_geoNormal(p0, p1, q0);

		auto v2 = [ ( w2.lat - p0.lat), ( w2.lon - p0.lon) ];
		auto u2 = v2[0] / n[0];													//assert ( abs( v2[0] / n[0] - v2[1] / n[1] ) <= 0.00001 );


		auto w3 = drop_geoNormal(p0, p1, q1);

		auto v3 = [ ( w3.lat - p0.lat), ( w3.lon - p0.lon) ];
		auto u3 = v3[0] / n[0];													//assert ( abs( v3[0] / n[0] - v3[1] / n[1] ) <= 0.00001);


		double[] t = [u0,u1,u2,u3];
		auto s = new short[t.length];
		makeIndex ! ( "a < b") (t, s);											// returns the sorted index. because we want an output line [ 0,1,2,3] or [3,2,0,1] ... and not the absolute locations...

		return s;


	}

	waypoint drop_geoNormal_pointToline(double [] p, field.rawData p0, field.rawData p1) {

		waypoint wp = new waypoint();

		double [] sp = new double[] (0);
		sp = p.gdup;

		double[] tlp0 = new double[] (0);
		tlp0 =  [p0.lat, p0.lon];

		double[] tlp1 = new double[] (0);
		tlp1 =  [p1.lat, p1.lon];

		auto w = calculate_geoNormal( sp, tlp0, tlp1);

		wp.lat = w[0];
		wp.lon = w[1];

		return wp;

	}

	waypoint drop_geoNormal(field.rawData p0, field.rawData p1, field.rawData q) {

		waypoint wp = new waypoint();

		double [] sp = new double[] (0);
		sp = [q.lat, q.lon];

		double[] tlp0 = new double[] (0);
		tlp0 =  [p0.lat, p0.lon];

		double[] tlp1 = new double[] (0);
		tlp1 =  [p1.lat, p1.lon];

		auto w = calculate_geoNormal( sp, tlp0, tlp1);

		wp.lat = w[0];
		wp.lon = w[1];

		return wp;

	}

	double calculate_maxSweepDist(int [] fld) {																// write("checking typical distace for : "); writeln(fld);
																											// return the maximum distance between sweeps...


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		double dMax = 0;

		for (int sIdx = 0; sIdx < fld.length; sIdx++) {

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];

			for (int sJdx = 0; sJdx < fld.length; sJdx++) {

				if ( sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];


				for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

					auto lineI = sweepI[lIdx];

					auto d = calculate_linetoSweepDistance_abreast(lineI, sweepJdx);
					if ( d > dMax) {																		// writeln("Distance increased");writeln(d);//// // readln;
						dMax = d;


						/+
						foreach( fswp; fld) {

							auto s = this.sweeps[fswp];														//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int j = 0; j < s.length; j++) {



								auto p0 = (*rd) [this.allLines[s[j]][0]];
								auto p1 = (*rd) [this.allLines[s[j]][1]];

																											// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto GREEN = Color4f(20.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
									drawLine_png(this.map,GREEN,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

								}



							}



						}

						auto si = this.sweeps[sweepIdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < si.length; j++) {



							auto p0 = (*rd) [this.allLines[si[j]][0]];
							auto p1 = (*rd) [this.allLines[si[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[si[j]][0]; ij < this.allLines[si[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}


						auto sj = this.sweeps[sweepJdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < sj.length; j++) {



							auto p0 = (*rd) [this.allLines[sj[j]][0]];
							auto p1 = (*rd) [this.allLines[sj[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[sj[j]][0]; ij < this.allLines[sj[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}

																											write("distance : "); writeln(d);
																											draw_map();  // readln;
						+/



					}

				}

			}

		}																									// write("returning distance is .."); writeln(dMax);// // // readln;

		return dMax;

	}

	double calculate_typicalSweepDist(int [] fld) {															// write("checking typical distace for : ");
																											// writeln(fld);// return the maximum distance between sweeps...


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;



		double [] all_minDists ;

		for ( int i = 0; i < fld.length; i++) {

			auto test_sweep = this.sweeps[fld[i]];

			for (int j = 0; j < test_sweep.length; j++) {

				auto test_line = this.allLines [ test_sweep[j]];
				auto d_line_toOtherSweeps = new double[] (0);

				for ( int k = 0; k < fld.length; k++) {

					auto d = this.calculate_linetoSweepDistance_abreast(test_sweep[j], fld[k]);
					if(d != -1 && d > 0.000001 ) d_line_toOtherSweeps ~= d;

				}																							// write("typical distance : ");writeln(d_line_toOtherSweeps); //// // readln;

				/+
				auto halfRangeLimit = to!ulong(floor(to!double(d_line_toOtherSweeps.length/2)));
				d_line_toOtherSweeps.sort();
				+/

				auto line_closest = d_line_toOtherSweeps.minElement;

				/+find_jenksMean( d_line_toOtherSweeps[0 .. halfRangeLimit ] )+/

				all_minDists ~= line_closest;

			}

		}

		/+
		double[] dstore ;

		for (int sIdx = 0; sIdx < fld.length; sIdx++) {

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];

			for (int sJdx = 0; sJdx < fld.length; sJdx++) {

				if ( sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];


				for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

					auto lineI = sweepI[lIdx];

					auto d = calculate_linetoSweepDistance_abreast(lineI, sweepJdx);
					if(d != -1) dstore ~= d;

				}

			}

		}																									// write("distance is .."); writeln(dMax);// // // readln;
		dstore.sort();
		dstore.length -= dstore.uniq().copy(dstore).length;
																											// writeln(dstore);
		return find_jenksMean(dstore);
		+/

		if (all_minDists.length == 0) all_minDists ~= this.shrinkstep;										// writeln(all_minDists);
		return find_jenksMean(all_minDists) /+ all_minDists.maxElement+/;
	}

	double calculate_typicalMaxSweepDist(int [] fld) {															// write("checking typical distace for : ");
																											// writeln(fld);// return the maximum distance between sweeps...


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;



		double [] all_minDists ;

		for ( int i = 0; i < fld.length; i++) {

			auto test_sweep = this.sweeps[fld[i]];

			for (int j = 0; j < test_sweep.length; j++) {

				auto test_line = this.allLines [ test_sweep[j]];
				auto d_line_toOtherSweeps = new double[] (0);

				for ( int k = 0; k < fld.length; k++) {

					auto d = this.calculate_linetoSweepDistance_abreast(test_sweep[j], fld[k]);				// writeln(d);
					if(d != -1 && d > 0.000001) d_line_toOtherSweeps ~= d;

				}																							// write("typical distance : ");writeln(d_line_toOtherSweeps); //// // readln;

				/+
				auto halfRangeLimit = to!ulong(floor(to!double(d_line_toOtherSweeps.length/2)));
				d_line_toOtherSweeps.sort();
				+/																							// writeln(d_line_toOtherSweeps);

				if ( d_line_toOtherSweeps.length >= 2) {
					auto line_closest = d_line_toOtherSweeps.minElement;
					/+find_jenksMean( d_line_toOtherSweeps[0 .. halfRangeLimit ] )+/
					all_minDists ~= line_closest;
				}

			}

		}

		/+
		double[] dstore ;

		for (int sIdx = 0; sIdx < fld.length; sIdx++) {

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];

			for (int sJdx = 0; sJdx < fld.length; sJdx++) {

				if ( sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];


				for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

					auto lineI = sweepI[lIdx];

					auto d = calculate_linetoSweepDistance_abreast(lineI, sweepJdx);
					if(d != -1) dstore ~= d;

				}

			}

		}																									// write("distance is .."); writeln(dMax);// // // readln;
		dstore.sort();
		dstore.length -= dstore.uniq().copy(dstore).length;
																											// writeln(dstore);
		return find_jenksMean(dstore);
		+/

		//all_minDists.sort();

		if (all_minDists.length == 0) all_minDists ~= this.shrinkstep;										// writeln(all_minDists);

		all_minDists.sort();																				// writeln(all_minDists);

		if (all_minDists.length > 5) all_minDists = all_minDists[$-5 .. $-1];								// writeln(all_minDists.maxElement); // ignoring the last, large one.

		return /+mean(all_minDists) +/ all_minDists.maxElement;
	}

	/+
	double calculate_avgSweepDist_pairwise(int [] fld) {																// write("checking typical distace for : "); writeln(fld);
																											// return the maximum distance between sweeps...
																											//// when this is called, seeps are ALREADY abreast.


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		double dMax = 0;

		double [] ds ;


		/+

		for (int sIdx = 0; sIdx < to!int(fld.length)-1; sIdx++) {											// write("sidx is :"); writeln(sIdx);

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];															// write("sweep I foind ..");writeln(sweepI);


			for (int sJdx = sIdx+1; sJdx < to!int(fld.length); sJdx++) {									// write("sjdX is :"); writeln(sJdx);

				if(sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];
				auto sweepJ = this.sweeps[sweepJdx];														// write("sweep found : "); writeln(sweepJ);

				auto d_sweepToSweep = calculate_sweepDistance ( sweepIdx, sweepJdx);
				if ( d_sweepToSweep > 2*  this.maxLineDist) return d_sweepToSweep;

				for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

					auto lineI = this.allLines[sweepI[lIdx]];												// writeln("line I found");
					for ( int lJdx = 0; lJdx < sweepJ.length; lJdx ++) {

						auto lineJ = this.allLines[sweepJ[lJdx]];											// writeln("line J found");
						/+
						foreach( fswp; fld) {

							auto s = this.sweeps[fswp];														//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int j = 0; j < s.length; j++) {



								auto p0 = (*rd) [this.allLines[s[j]][0]];
								auto p1 = (*rd) [this.allLines[s[j]][1]];

																											// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto GREEN = Color4f(20.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
									drawLine_png(this.map,GREEN,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

								}



							}



						}

						auto si = this.sweeps[sweepIdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < si.length; j++) {



							auto p0 = (*rd) [this.allLines[si[j]][0]];
							auto p1 = (*rd) [this.allLines[si[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[si[j]][0]; ij < this.allLines[si[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}


						auto sj = this.sweeps[sweepJdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < sj.length; j++) {



							auto p0 = (*rd) [this.allLines[sj[j]][0]];
							auto p1 = (*rd) [this.allLines[sj[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[sj[j]][0]; ij < this.allLines[sj[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}

																											write("distance : "); writeln(d);
																											draw_map();  // readln;
						+/

						/+
						calculate_geoDistance_betweenLines
						auto d_lineToLine = calculate_linetoLineDistance(sweepI[lIdx], sweepJ[lJdx]);
						if( d_lineToLine > 2* this.maxLineDist) { 											writeln("line to line distance : " ~ to!string(d_lineToLine));
																											write("sweeps are : "); write(sweepIdx); write("; "); writeln(sweepJdx);
							if( ( sweepIdx == 1 ) || ( sweepIdx == 4 ) ) {

								auto s = this.sweeps[gfield[ii]];															//writeln(s);// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

								for (int j = 0; j < s.length; j++) {



									auto p0 = (*rd) [this.allLines[s[j]][0]];
									auto p1 = (*rd) [this.allLines[s[j]][1]];



									double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
									double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
									double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
									auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

									if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
									if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



									/+
																													// this is for ...… drawing the inner line segments in a single interpolated straight line
									for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

										auto pp1 = (*rd) [ij];
										auto pp2 = (*rd) [ij+1];

										double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
										double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
										double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
										auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
										auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

										if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



									}
									+/


								}



							}

							continue;
						}
						+/

						for ( int li =  lineI[0]; li < lineI[1]; li++) {

							auto liSeg = [li, li+1];												// writeln(0);
							auto p0 = (*rd)[liSeg[0]];												// writeln(2);
							auto p1 = (*rd)[liSeg[1]];												// writeln(3);

							auto midPoint = [ (p0.lat +  p1.lat) / 2.0 , ( p0.lon +  p1.lon) / 2.0  ];												// writeln(7);


							for ( int lj =  lineJ[0]; lj < lineJ[1]; lj++) {


								auto ljSeg = [lj, lj+1];												// writeln(1);



								auto q0 = (*rd)[ljSeg[0]];												// writeln(4);
								auto q1 = (*rd)[ljSeg[1]];												// writeln(5);

								//auto abr = calculate_abreastRatio(p0,p1,q0,q1);							write("abreast ratio is : ") ;writeln(abr);

								// auto d_lineToLine = calculate_geoDistance_betweenLines(p0.lat,p1.lat, q0.lat, q1.lat, p0.lon, p1.lon, q0.lon, q1.lon);
								// if ( d_lineToLine > 2*this.maxLineDist) continue;
																										//// ABOVE CALCULATION IS SLOWING DOWN THE CODE. NOT NEEDED


																										/+
																										if ( li == lineI[1] -1 ) {

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(250.00/255.00,220.00/255.00,50.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

								yy1 = to!int(this.multiplier_global * (this.latMax_global - q0.lat) + offsetX);
								yy2 = to!int(this.multiplier_global * (this.latMax_global - q1.lat) + offsetX);
								xx1 = to!int((this.multiplier_global * (q0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								xx2 = to!int((this.multiplier_global * (q1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								VILT0 = Color4f(250.00/255.00,220.00/255.00,50.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));


																											draw_map(); readln();
																										}
																										+/




								// if ( abr < this.minOverlap) continue;

								auto w = drop_geoNormal_pointToline(midPoint, q0, q1);												// writeln(8);
								auto a = calculate_geoDistance_vincenty(w.lat, midPoint[0], w.lon, midPoint[1]);												// writeln(9);

								if ( !isNaN(a) && a > 0) {
									ds ~= a;
								}
							}																				// writeln(10);

						}																					// writeln(11);


					}																						// writeln(12);


				}																							// writeln(13);

			}																								// writeln(14);

		}																									// write("returning distance is .."); writeln(ds);// // // readln;


		+/

		int[][] pnk ;
		pnk.length = fld.length;

		// enum threadCount = 2;
		// auto prTaskPool = new TaskPool(threadCount);

		/+
		scope (exit) {
			prTaskPool.finish();
		} +/

		// enum workUnitSize = 100;

		for(int i = 0; i < fld.length; i++) {

			auto sweepIdx = fld[i];
			auto sweepI = this.sweeps[sweepIdx];

			for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

				auto lineI = this.allLines[sweepI[lIdx]];
				for ( int li =  lineI[0]; li <= lineI[1]; li++) {
					pnk[i] ~= li;
				}


			}


		}																									// writeln(-3);

		ds.length = (pnk[0].length - 1) * (pnk[1].length-1);												// writeln(-2);

		for(int i = 0; i < ds.length; i++) ds[i] = -9;														// set a dummy value;



		auto pnts_mod = pnk[0][0 .. pnk[0].length -1];													// writeln(-1);

		for ( int i = 0; i < pnk[0].length-1; i++) {
			auto p0 = (*rd)[pnk[0][i]];																	// writeln(0);
			auto p1 = (*rd)[pnk[0][i+1]];																	// writeln(1);

			auto midPoint = [ (p0.lat +  p1.lat) / 2.0 , ( p0.lon +  p1.lon) / 2.0  ];						// writeln(1.5);

			for (int j = 0; j < pnk[1].length -1; j++) {													//writeln(j);

				auto q0 = (*rd)[pnk[1][j]];																// writeln(2);
				auto q1 = (*rd)[pnk[1][j+1]];																// writeln(3);
				auto w = drop_geoNormal_pointToline(midPoint, q0, q1);										// writeln(4);
				auto a = calculate_geoDistance_vincenty(w.lat, midPoint[0], w.lon, midPoint[1]);												// writeln(9);

				if ( !isNaN(a) && a > 0) {																	// writeln(5);
					ds[i * pnts_mod.length + j] = a;														// writeln(6);
				}

			}

																											//writeln("parallelForeach finished");

		}

																											//writeln(ds);
		double [] ds_new;
		for(int i = 0; i < ds.length; i++) {																//writeln("parsing ds : " ~to!string(i));
			if (ds[i] != -9) {
				ds_new ~= ds[i];
			}
		}

		/+
		for (int sIdx = 0; sIdx < to!int(fld.length)-1; sIdx++) {											// write("sidx is :"); writeln(sIdx);

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];															// write("sweep I foind ..");writeln(sweepI);

			double[][] linesI_midPoints ;
			for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {
				auto lineI = this.allLines[sweepI[lIdx]];													// writeln("line I found");
				for ( int li =  lineI[0]; li < lineI[1]; li++) {

					auto liSeg = [li, li+1];																// writeln(0);
					auto p0 = (*rd)[liSeg[0]];																// writeln(2);
					auto p1 = (*rd)[liSeg[1]];																// writeln(3);
																											// writeln(10);
					auto midPoint = [ (p0.lat +  p1.lat) / 2.0 , ( p0.lon +  p1.lon) / 2.0  ];
					linesI_midPoints ~= midPoint;
				}
			}

			for (int sJdx = sIdx+1; sJdx < to!int(fld.length); sJdx++) {									// write("sjdX is :"); writeln(sJdx);

				if(sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];
				auto sweepJ = this.sweeps[sweepJdx];														// write("sweep found : "); writeln(sweepJ);

				for ( int lJdx = 0; lJdx < sweepJ.length; lJdx ++) {

					auto lineJ = this.allLines[sweepJ[lJdx]];
					for ( int lj =  lineJ[0]; lj < lineJ[1]; lj++) {

						auto ljSeg = [lj, lj+1];															// writeln(1);

						auto q0 = (*rd)[ljSeg[0]];															// writeln(4);
						auto q1 = (*rd)[ljSeg[1]];															// writeln(5);

						for( int im =0; im < linesI_midPoints.length; im++) {


							auto w = drop_geoNormal_pointToline(linesI_midPoints[im], q0, q1);							// writeln(8);
							auto a = calculate_geoDistance_vincenty(w.lat, linesI_midPoints[im][0], w.lon, linesI_midPoints[im][1]);// writeln(9);

							if ( !isNaN(a) && a > 0) {
								ds ~= a;
							}

						}


					}

				}
																											// writeln(13);

			}																								// writeln(14);

		}
		+/
																											// writeln("completed. Returning :"); writeln(ds_new);
																											//writeln(pnts); exit(0);

		if( ds_new.length == 0) return -1;																		// even tho, there was a case of abreast calculation, it failed (lines too skew)
																											// thus returning -1

		else {																								//writeln(7); writeln(ds_new);
			auto b = find_jenksMean(ds_new);																//writeln(8); writeln(b);
			return b;
		}

	}
	+/





    double calculate_avgSweepDist_pairwise(int [] fld) {																// write("checking typical distace for : "); writeln(fld);
																											// return the maximum distance between sweeps...
																											//// when this is called, seeps are ALREADY abreast.


		field.rawData [] * rd ;
		rd = cast (field.rawData [] *)  dataSet;


		double offsetY = londiff_global * 0.05 * this.multiplier_global;
		double offsetX = latdiff_global * 0.05 * this.multiplier_global;

		double dMax = 0;

		double [] ds ;



		for (int sIdx = 0; sIdx < to!int(fld.length)-1; sIdx++) {											// write("sidx is :"); writeln(sIdx);

			auto sweepIdx = fld[sIdx];
			auto sweepI = this.sweeps[sweepIdx];															// write("sweep I foind ..");writeln(sweepI);


			for (int sJdx = sIdx+1; sJdx < to!int(fld.length); sJdx++) {									// write("sjdX is :"); writeln(sJdx);

				if(sIdx == sJdx) continue;

				auto sweepJdx = fld[sJdx];
				auto sweepJ = this.sweeps[sweepJdx];														// write("sweep found : "); writeln(sweepJ);

				auto d_sweepToSweep = calculate_sweepDistance ( sweepIdx, sweepJdx);
				if ( d_sweepToSweep > 2*  this.maxLineDist) return d_sweepToSweep;

				for( int lIdx = 0; lIdx <sweepI.length; lIdx ++) {

					auto lineI = this.allLines[sweepI[lIdx]];												// writeln("line I found");
					for ( int lJdx = 0; lJdx < sweepJ.length; lJdx ++) {

						auto lineJ = this.allLines[sweepJ[lJdx]];											// writeln("line J found");
						/+
						foreach( fswp; fld) {

							auto s = this.sweeps[fswp];														//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

							for (int j = 0; j < s.length; j++) {



								auto p0 = (*rd) [this.allLines[s[j]][0]];
								auto p1 = (*rd) [this.allLines[s[j]][1]];

																											// this is for ...… drawing the inner line segments in a single interpolated straight line
								for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

									auto pp1 = (*rd) [ij];
									auto pp2 = (*rd) [ij+1];

									double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
									double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
									double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto GREEN = Color4f(20.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
									drawLine_png(this.map,GREEN,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

								}



							}



						}

						auto si = this.sweeps[sweepIdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < si.length; j++) {



							auto p0 = (*rd) [this.allLines[si[j]][0]];
							auto p1 = (*rd) [this.allLines[si[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[si[j]][0]; ij < this.allLines[si[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}


						auto sj = this.sweeps[sweepJdx];													//write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

						for (int j = 0; j < sj.length; j++) {



							auto p0 = (*rd) [this.allLines[sj[j]][0]];
							auto p1 = (*rd) [this.allLines[sj[j]][1]];

																														// this is for ...… drawing the inner line segments in a single interpolated straight line
							for(int ij = this.allLines[sj[j]][0]; ij < this.allLines[sj[j]][1]; ij++) {

								auto pp1 = (*rd) [ij];
								auto pp2 = (*rd) [ij+1];

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(10.00/255.00,120.00/255.00,250.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

							}



						}

																											write("distance : "); writeln(d);
																											draw_map();  // readln;
						+/

						/+
						calculate_geoDistance_betweenLines
						auto d_lineToLine = calculate_linetoLineDistance(sweepI[lIdx], sweepJ[lJdx]);
						if( d_lineToLine > 2* this.maxLineDist) { 											writeln("line to line distance : " ~ to!string(d_lineToLine));
																											write("sweeps are : "); write(sweepIdx); write("; "); writeln(sweepJdx);
							if( ( sweepIdx == 1 ) || ( sweepIdx == 4 ) ) {

								auto s = this.sweeps[gfield[ii]];															//writeln(s);// write("sweep lenght is"); writeln(calculate_sweepLength(guessedField[ii]));

								for (int j = 0; j < s.length; j++) {



									auto p0 = (*rd) [this.allLines[s[j]][0]];
									auto p1 = (*rd) [this.allLines[s[j]][1]];



									double y0 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
									double y1 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
									double x0 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									double x1 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
									auto CYAN0 = Color4f(0,120.00/255.00,250.00/255.00);					//writeln(0);
									auto CYAN1 = Color4f(0,250.00/255.00,120.00/255.00);					//writeln(0);

									if (i % 2 == 0) drawLine_png(this.map,CYAN0,to!int(x0),to!int(y0),to!int(x1),to!int(y1));
									if (i % 2 == 1) drawLine_png(this.map,CYAN1,to!int(x0),to!int(y0),to!int(x1),to!int(y1));



									/+
																													// this is for ...… drawing the inner line segments in a single interpolated straight line
									for(int ij = this.allLines[s[j]][0]; ij < this.allLines[s[j]][1]; ij++) {

										auto pp1 = (*rd) [ij];
										auto pp2 = (*rd) [ij+1];

										double yy1 = to!int(this.multiplier_global * (this.latMax_global - pp1.lat) + offsetX);
										double yy2 = to!int(this.multiplier_global * (this.latMax_global - pp2.lat) + offsetX);
										double xx1 = to!int((this.multiplier_global * (pp1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										double xx2 = to!int((this.multiplier_global * (pp2.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
										auto VILT0 = Color4f(220.00/255.00,10.00/255.00,20.00/255.00);							//writeln(0);
										auto VILT1 = Color4f(10.00/255.00,250.00/255.00,120.00/255.00);							//writeln(0);
										auto VILT2 = Color4f(220.00/255.00,250.00/255.00,10.00/255.00);							//writeln(0);

										if (i % 3 == 0) drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 1) drawLine_png(this.map,VILT1,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));
										else if (i % 3 == 2) drawLine_png(this.map,VILT2,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));



									}
									+/


								}



							}

							continue;
						}
						+/

						for ( int li =  lineI[0]; li < lineI[1]; li++) {

							auto liSeg = [li, li+1];												// writeln(0);
							auto p0 = (*rd)[liSeg[0]];												// writeln(2);
							auto p1 = (*rd)[liSeg[1]];												// writeln(3);

							auto midPoint = [ (p0.lat +  p1.lat) / 2.0 , ( p0.lon +  p1.lon) / 2.0  ];												// writeln(7);


							for ( int lj =  lineJ[0]; lj < lineJ[1]; lj++) {


								auto ljSeg = [lj, lj+1];												// writeln(1);



								auto q0 = (*rd)[ljSeg[0]];												// writeln(4);
								auto q1 = (*rd)[ljSeg[1]];												// writeln(5);

								//auto abr = calculate_abreastRatio(p0,p1,q0,q1);							write("abreast ratio is : ") ;writeln(abr);

								// auto d_lineToLine = calculate_geoDistance_betweenLines(p0.lat,p1.lat, q0.lat, q1.lat, p0.lon, p1.lon, q0.lon, q1.lon);
								// if ( d_lineToLine > 2*this.maxLineDist) continue;
																										//// ABOVE CALCULATION IS SLOWING DOWN THE CODE. NOT NEEDED


																										/+
																										if ( li == lineI[1] -1 ) {

								double yy1 = to!int(this.multiplier_global * (this.latMax_global - p0.lat) + offsetX);
								double yy2 = to!int(this.multiplier_global * (this.latMax_global - p1.lat) + offsetX);
								double xx1 = to!int((this.multiplier_global * (p0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								double xx2 = to!int((this.multiplier_global * (p1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								auto VILT0 = Color4f(250.00/255.00,220.00/255.00,50.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));

								yy1 = to!int(this.multiplier_global * (this.latMax_global - q0.lat) + offsetX);
								yy2 = to!int(this.multiplier_global * (this.latMax_global - q1.lat) + offsetX);
								xx1 = to!int((this.multiplier_global * (q0.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								xx2 = to!int((this.multiplier_global * (q1.lon - this.lonMin_global) + offsetY) * cos(this.latMin_global * 3.141592 / 180.00));
								VILT0 = Color4f(250.00/255.00,220.00/255.00,50.00/255.00);							//writeln(0);
								drawLine_png(this.map,VILT0,to!int(xx1),to!int(yy1),to!int(xx2),to!int(yy2));


																											draw_map(); readln();
																										}
																										+/




								// if ( abr < this.minOverlap) continue;

								auto w = drop_geoNormal_pointToline(midPoint, q0, q1);												// writeln(8);
								auto a = calculate_geoDistance_vincenty(w.lat, midPoint[0], w.lon, midPoint[1]);												// writeln(9);

								if ( !isNaN(a) && a > 0) {
									ds ~= a;
								}
							}																				// writeln(10);

						}																					// writeln(11);


					}																						// writeln(12);


				}																							// writeln(13);

			}																								// writeln(14);

		}																									// write("returning distance is .."); writeln(ds);// // // readln;



																											// writeln("completed. Returning :"); writeln(ds_new);
																											//writeln(pnts); exit(0);

		if( ds.length == 0) return -1;																		// even tho, there was a case of abreast calculation, it failed (lines too skew)
																											// thus returning -1

		else {																								//writeln(7); writeln(ds_new);
			auto b = find_jenksMean(ds);																//writeln(8); writeln(b);
			return b;
		}

	}







}


struct Point { double x, y; }
struct Edge { Point a, b; }
struct Figure {
	Edge[] edges;
}

bool contains(in Figure poly, in Point p) pure nothrow @safe @nogc {
	static bool raySegI(in Point p, in Edge edge)
	pure nothrow @safe @nogc {
		enum double epsilon = 0.00001;
		with (edge) {
			if (a.y > b.y)
				//swap(a, b); // if edge is mutable
				return raySegI(p, Edge(b, a));
			if (p.y == a.y || p.y == b.y)
				//p.y += epsilon; // if p is mutable
				return raySegI(Point(p.x, p.y + epsilon), edge);
			if (p.y > b.y || p.y < a.y || p.x > max(a.x, b.x))
				return false;
			if (p.x < min(a.x, b.x))
				return true;
			immutable blue = (abs(a.x - p.x) > double.min_normal) ?
							((p.y - a.y) / (p.x - a.x)) :
							double.max;
			immutable red = (abs(a.x - b.x) > double.min_normal) ?
							((b.y - a.y) / (b.x - a.x)) :
							double.max;
			return blue >= red;
		}
	}

	return poly.edges.count!(e => raySegI(p, e)) % 2;
}

bool intersects(in Figure poly, in Point p0, in Point p1){
	
	bool res = false;
	
	for (int i = 0 ; i < poly.edges.length; i++) {
	
		auto P = calculate_geoArcIntersection ([[p0.x,p0.y],[p1.x, p1.y]], [[poly.edges[i].a.x,poly.edges[i].a.y], [poly.edges[i].b.x,poly.edges[i].b.y]]);

		if ( isNaN(P[0]) || isNaN (P[1]) || isInfinity (P[0]) || isInfinity (P [1])) continue;

		else {																								/+writeln("intersection found at : ");print_highPrecisionArray(P);
																											print_highPrecisionArray([poly.edges[i].a.x, poly.edges[i].a.y]);
																											print_highPrecisionArray([poly.edges[i].b.x, poly.edges[i].b.y]);
																											print_highPrecisionArray([p0.x, p0.y]);
																											print_highPrecisionArray([p1.x, p1.y]);
																											writeln(isBetween(poly.edges[i].a.x, poly.edges[i].b.x, P[0]) && isBetween(poly.edges[i].a.y, poly.edges[i].b.y, P[1]));
																											writeln(isBetween(p0.x,p1.x,P[0]) && isBetween(p0.y,p1.y,P[1]));
																											writeln("----");+/

			if ( 	isBetween(poly.edges[i].a.x, poly.edges[i].b.x, P[0]) && isBetween(poly.edges[i].a.y, poly.edges[i].b.y, P[1]) &&
					isBetween(p0.x,p1.x,P[0]) && isBetween(p0.y,p1.y,P[1])) {								/+writeln("intersection found at : ");print_highPrecisionArray(P);
																											print_highPrecisionArray([poly.edges[i].a.x, poly.edges[i].a.y]);
																											print_highPrecisionArray([poly.edges[i].b.x, poly.edges[i].b.y]);
																											print_highPrecisionArray([p0.x, p0.y]);
																											print_highPrecisionArray([p1.x, p1.y]);
																											writeln(isBetween(poly.edges[i].a.x, poly.edges[i].b.x, P[0]) && isBetween(poly.edges[i].a.y, poly.edges[i].b.y, P[1]));
																											writeln(isBetween(p0.x,p1.x,P[0]) && isBetween(p0.y,p1.y,P[1]));
																											writeln("----");+/
				res = true;
				break;
			}
		}
	
	}
	
	return res;
}

bool isBetween (double s, double e, double t) {

	bool res = false;
	
	if ( (t < max(s,e)  || isClose(t, max(s,e))) &&  (t > min(s,e)  || isClose(t, min(s,e)))) res = true;
	
	return res;

}

double calculate_geoDistance(double lat1, double lat2, double lon1, double lon2) {

	double a = pow(( sin ( ( lat1 * 3.141592/180.00 - lat2 * 3.141592 / 180.00 )  / 2.00) ) , 2);
	double b = cos( lat1 * 3.141592 / 180.00 ) * cos(lat2 * 3.141592 / 180.00);
	double c = pow(( sin ( ( lon1 * 3.141592 / 180.00 - lon2 * 3.141592 / 180.00) / 2.00)  ) ,2);
	
	double dist = 2 * 6400000 * asin (sqrt ( a+ b * c )	);
	return dist;

}

double calculate_geoDistance_vincenty(double lat1, double lat2, double lon1, double lon2) {

	lat1 = lat1 * PI / 180.00;
	lat2 = lat2 * PI / 180.00;
	lon1 = lon1 * PI / 180.00;
	lon2 = lon2 * PI / 180.00;


	double a = 6378137.0 ;																					// radius of Earth in the WGS 84 datum
	double f = 1/298.257223563;																				// eccentricity of Earth in WGS84
	double b = ( 1 - f) * a;

	double U1 = atan( ( 1 -f) * lat1);
	double U2 = atan( ( 1 -f) * lat2);
	double L = lon2 - lon1;

	double lambda = L;

	double sinSigma;
	double cosSigma;
	double sigma;
	double sinAlpha;
	double cosAlpha;
	double cos2SigM;
	double C ;
	double lambdaPrior ;

	sinSigma = sqrt ( ( cos(U1) * sin ( lambda))^^2 + ( cos(U1)* sin(U2) - sin(U1)* cos(U2)* cos(lambda)  )^^2 );
	cosSigma = sin(U1) * sin(U2) + cos(U1) * cos(U2) * cos(lambda);
	sigma    = atan2(sinSigma, cosSigma);
	sinAlpha = ( cos(U1) * cos (U2) * sin(lambda)) / sinSigma;
	cosAlpha = ( 1 - sinAlpha * sinAlpha);
	cos2SigM = cosSigma  - ( 2 * sin (U1) * sin (U2)) / ( 1 - sinAlpha * sinAlpha);
	C        = f / 16.00 * ( cosAlpha * cosAlpha) * ( 4  + f * ( 4 - 3 * ( cosAlpha * cosAlpha) ));
	lambda          = L + ( 1 - C) * f * sinAlpha * (  sigma + C * sinSigma * ( cos2SigM + C * cosSigma * ( - 1 +  2 * cos2SigM * cos2SigM)  )  );
	lambdaPrior = lambda + 10;
																											//write("lambda is now :"); writeln(lambda); // // readln;

	while ( abs(lambdaPrior - lambda) >= 0.0002) {

		sinSigma = sqrt ( ( cos(U1) * sin ( lambda))^^2 + ( cos(U1)* sin(U2) - sin(U1)* cos(U2)* cos(lambda)  )^^2 );
		cosSigma = sin(U1) * sin(U2) + cos(U1) * cos(U2) * cos(lambda);
		sigma    = atan2(sinSigma, cosSigma);
		sinAlpha = ( cos(U1) * cos (U2) * sin(lambda)) / sinSigma;
		cosAlpha = sqrt( 1 - sinAlpha * sinAlpha);
		cos2SigM = cosSigma  - ( 2 * sin (U1) * sin (U2)) / ( 1 - sinAlpha * sinAlpha);
		C        = f / 16.00 * ( cosAlpha * cosAlpha) * ( 4  + f * ( 4 - 3 * ( cosAlpha * cosAlpha) ));
		lambdaPrior  = lambda;
		lambda          = L + ( 1 - C) * f * sinAlpha * (  sigma + C * sinSigma * ( cos2SigM + C * cosSigma * ( - 1 +  2 * cos2SigM * cos2SigM)  )  );
																											//write("lambda is now :"); writeln(lambda); // // readln;
	}

																											//write("cosAlpha is "); writeln(cosAlpha);
	double usqr = cosAlpha * cosAlpha * ( ( a*a - b*b) / (b*b));											//write("usqr is : "); writeln(usqr);
	double A    = 1 + usqr / 16384 * ( 4096 + usqr * ( - 768 + usqr * (320  - 175 * usqr) ) );				//write("A is : ");writeln(A);
	double B	=     usqr /  1024 * (  256 + usqr * ( - 128 + usqr * ( 74  -  47 * usqr) ) );
	double deltaSigma = B * sinSigma * ( cos2SigM + 1/4.00 * B * ( cosSigma *  ( - 1 + 2 * cos2SigM*cos2SigM) - B / 6.0 * cos2SigM* ( -3 + 4  * sinSigma*sinSigma) * ( -3 + 4 * cos2SigM*cos2SigM)  )  );

	double s = b*A*(sigma -deltaSigma);																		//writeln(toStringLikeInCSharp(b));
																											//writeln(toStringLikeInCSharp(A));
																											//writeln(toStringLikeInCSharp((sigma -deltaSigma)));


// 	double a = pow(( sin ( ( lat1 * 3.141592/180.00 - lat2 * 3.141592 / 180.00 )  / 2.00) ) , 2);
// 	double b = cos( lat1 * 3.141592 / 180.00 ) * cos(lat2 * 3.141592 / 180.00);
// 	double c = pow(( sin ( ( lon1 * 3.141592 / 180.00 - lon2 * 3.141592 / 180.00) / 2.00)  ) ,2);
//
// 	double dist = 2 * 6400000 * asin (sqrt ( a+ b * c )	);
// 	return dist;

	if ( isNaN(s)) {

		if ( isClose(lat1, lat2) && isClose(lon1, lon2)) s = 0.000001;

	}

	return s;

}

double calculate_geoHeading(double [] x, double [] y , double theta_res = 1 * PI /180.00 , double rho_res = 100) {

	/+ +++++++++
	++ This function will return the heading of the best fit line
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/

	double score = -9999;
	double theta_min = 0;
	double theta_max = 2*PI;
	double rho_min   = 0;

	double xDiff     = x.maxElement - x.minElement;
	double yDiff     = y.maxElement - y.minElement;

	int cnt = to!int(x.length);																				// y.length is the same




	double rho_max   = sqrt ( xDiff * xDiff + yDiff * yDiff ) ;
	double rho_diff  = rho_max - rho_min;


	for ( double theta = theta_min; theta <= theta_max; theta = theta + theta_res) {						// it can reach 2PI, thus <= is used and not just <

		for ( double rho = rho_min; rho <= rho_max; rho = rho + (rho_diff / rho_res)) {


			auto line_guess =[ theta, rho];																	// hesse normal form of a line as the tangent of a circle.


			double RMSE = 0;
			double tempScore = 0;

			for (int xi = 0; xi < cnt; xi++) {

				auto currPnt = [ x[xi], y[xi]];																// picked the point



			}

		}

	}

	double r;

	/+
	real xMean = mean(x);
	real yMean = mean(y);

	real denom = 0;
	real numer = 0;

	//double cookD =

	for( int i = 0; i < x.length; i++) {

		numer += (x[i] - xMean) * (y[i] - yMean);
		denom += (x[i] - xMean) * (x[i] - xMean);

	}

	real b1 = numer / denom ;
	real b0 = yMean - (b1 * xMean);																			toStringLikeInCSharp(denom);


	real y0 = b0 + b1 * x[0];
	real x0 = x[0];

	real yn = b0 + b1 * x[$-1];
	real xn = x[$-1];

	// check if algorithm failed...



	r = atan2((yn-y0), (xn-x0));																			print_highPrecisionArray([yn,y0]);print_highPrecisionArray([xn,x0]);
																											print_highPrecisionArray([(yn-y0), (xn-x0)]);
																											print_highPrecisionArray([b0,b1]);
	foreach(XX; x) {

		auto YY =  b0 + b1 * XX;
		print_highPrecision_geoArray([YY, XX]);
	}
	+/



	//for ( double

	return r;

}

double  calculate_geoLineFit_angle (double [] x, double [] y , double theta_res = 1 * PI /180.00 , double rho_res = 100) {

	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0.00001;
	double theta_max = PI+0.00001;
	double rho_min   = 0.1/150000;


	double xDiff     = x.maxElement - x.minElement;
	double yDiff     = y.maxElement - y.minElement;

	double xDiff_seq = x[$-1] - x[0];
	double yDiff_seq = y[$-1] - y[0];


	int cnt = to!int(x.length);																				// y.length is the same




	double rho_max   = sqrt ( xDiff * xDiff + yDiff * yDiff ) / 2.0 ;										// half diagonal picked

	double xOrigin = xDiff / 2.0 + x.minElement;
	double yOrigin = yDiff / 2.0 + y.minElement;


	double bestTheta;


	double bestRho;
	double[] rmsALL = new double [] (0);

	double rho_diff  = rho_max - rho_min;


	for ( double theta = theta_min; theta <= theta_max; theta = theta + theta_res) {						// it can reach 2PI, thus <= is used and not just <

		double rho = rho_min;


		auto line_guess =[ theta, rho];																	// hesse normal form of a line as the tangent of a circle.

		auto m = tan (theta);																		// slope of the attempted hugh tangent line
		auto c = yOrigin - (m * xOrigin);					// c of y = mx + c


		double RMSE = 0;
		double tempScore = 0;

		double [] allErr = new double [] (0);
		for (int xi = 0; xi < cnt; xi++) {

			auto currPnt = [ x[xi], y[xi]];																// picked the point

			double t1 = m * currPnt[0];																	// m*x
			double t2 = currPnt[1];																		// y
			double t3 = c;																				// c
			double t4 = sqrt ( 1 + m*m);																// sqrt of 1 + m^2

			double dist = abs ( ( t1  - t2 + t3) / t4);
			allErr ~= dist;
			RMSE = RMSE + dist;
		}

		tempScore = 1.0 / RMSE;																			// total score after ALL points

		if ( tempScore > score) {

			score = tempScore;
			bestTheta = theta;
			bestRho   = rho;
			rmsALL    = allErr.gdup;
		}

	}



	// now need to check if theta is correctly aligned ....




	double bestTheta_check  = atan2(yDiff_seq, xDiff_seq);													// get the large direction



	if (bestTheta_check ==    0 && bestTheta ==    0 ) bestTheta = bestTheta;
	if (bestTheta_check ==    0 && bestTheta ==   PI ) bestTheta = bestTheta_check;
	if (bestTheta_check >     0 && bestTheta_check <   PI && bestTheta >  0 && bestTheta <  PI ) bestTheta = bestTheta;
	if (bestTheta_check <     0 && bestTheta_check >  -PI && bestTheta >  0 && bestTheta <  PI ) bestTheta = bestTheta-PI;
	if (bestTheta_check ==    PI && bestTheta ==   PI ) bestTheta = bestTheta_check;
	if (bestTheta_check ==    PI && bestTheta ==   PI ) bestTheta = bestTheta;


	/+

	double bestTheta_option0 = bestTheta;
	double bestTheta_option1 = (bestTheta + PI) % 2*PI;

	bestTheta = abs( bestTheta - bestTheta_option0) < abs( bestTheta - bestTheta_option1) ? bestTheta_option0 : bestTheta_option1;

	+/
																											// write("raw_guess is : ");writeln(bestTheta_check*180/PI);
																											// write("fitted guess is : ");writeln(bestTheta*180/PI);

	return bestTheta; //[[ 1.0 / score, bestTheta], rmsALL];


}

double  calculate_geoLineFit_angle_raw_withSign (double [] x, double [] y ) {

	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0.00001;
	double theta_max = PI+0.00001;
	double rho_min   = 0.1/150000;


	double xDiff_seq = x[$-1] - x[0];
	double yDiff_seq = y[$-1] - y[0];


	double bestTheta = atan2(yDiff_seq, xDiff_seq) ;
	if (bestTheta <0.05 && bestTheta >0.05) bestTheta = 0;
	if (bestTheta > PI - 0.05 || bestTheta < -PI + 0.05) bestTheta = PI;


	return bestTheta; //[[ 1.0 / score, bestTheta], rmsALL];


}

double  calculate_geoLineFit_angle_raw (double [] x, double [] y ) {

	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0.00001;
	double theta_max = PI+0.00001;
	double rho_min   = 0.1/150000;


	double xDiff_seq = x[$-1] - x[0];
	double yDiff_seq = y[$-1] - y[0];


	double bestTheta = atan2(yDiff_seq, xDiff_seq) < 0 ? atan2(yDiff_seq, xDiff_seq) + PI : atan2(yDiff_seq, xDiff_seq);


	return bestTheta; //[[ 1.0 / score, bestTheta], rmsALL];


}

double find_jenksMean(double[] input) {

	auto nums = input;
	nums.sort();
	if (nums.length & 1) {																					// writeln(1);
		return nums[$ / 2];
	}
	else {																									// writeln(2);
		auto r = (nums[$ / 2 - 1] + nums[$ / 2]) / 2.0;														// writeln(3);
		return r;
	}

}

/+
double  calculate_geoLineFit_angle (double [] x, double [] y , double theta_res = 1 * PI /180.00 , double rho_res = 100) {

	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0.00001;
	double theta_max = PI+0.00001;
	double rho_min   = 0.1/150000;


	double xDiff     = x.maxElement - x.minElement;
	double yDiff     = y.maxElement - y.minElement;

	double xDiff_seq = x[$-1] - x[0];
	double yDiff_seq = y[$-1] - y[0];


	int cnt = to!int(x.length);																				// y.length is the same




	double rho_max   = sqrt ( xDiff * xDiff + yDiff * yDiff ) / 2.0 ;										// half diagonal picked

	double xOrigin = xDiff / 2.0 + x.minElement;
	double yOrigin = yDiff / 2.0 + y.minElement;


	double bestTheta;


	double bestRho;
	double[] rmsALL = new double [] (0);

	double rho_diff  = rho_max - rho_min;


	for ( double theta = theta_min; theta <= theta_max; theta = theta + theta_res) {						// it can reach 2PI, thus <= is used and not just <

		double rho = rho_min;


		auto line_guess =[ theta, rho];																	// hesse normal form of a line as the tangent of a circle.

		auto m = tan (theta);																		// slope of the attempted hugh tangent line
		auto c = ( yOrigin + rho * sin(theta)) - (m * (xOrigin + rho * cos(theta)));					// c of y = mx + c


		double RMSE = 0;
		double tempScore = 0;

		double [] allErr = new double [] (0);
		for (int xi = 0; xi < cnt; xi++) {

			auto currPnt = [ x[xi], y[xi]];																// picked the point

			double t1 = m * currPnt[0];																	// m*x
			double t2 = currPnt[1];																		// y
			double t3 = c;																				// c
			double t4 = sqrt ( 1 + m*m);																// sqrt of 1 + m^2

			double dist = abs ( ( t1  - t2 + t3) / t4);
			allErr ~= dist;
			RMSE = RMSE + dist;
		}

		tempScore = 1.0 / RMSE;																			// total score after ALL points

		if ( tempScore > score) {

			score = tempScore;
			bestTheta = theta;
			bestRho   = rho;
			rmsALL    = allErr.gdup;
		}

	}



	// now need to check if theta is correctly aligned ....




	double bestTheta_check  = atan2(yDiff_seq, xDiff_seq);													// get the large direction

	double bestTheta_option0 = bestTheta;
	double bestTheta_option1 = (bestTheta + PI) % (2*PI) > PI ? 2*PI - (bestTheta + PI) % (2*PI) : (bestTheta + PI) % (2*PI);



	double op0d =  abs( bestTheta_check - bestTheta_option0) > PI ? 2*PI -  abs( bestTheta_check - bestTheta_option0)  :  abs( bestTheta_check - bestTheta_option0);
	double op1d =  abs( bestTheta_check - bestTheta_option1) > PI ? 2*PI -  abs( bestTheta_check - bestTheta_option1)  :  abs( bestTheta_check - bestTheta_option1);



	bestTheta = op0d < op1d ? bestTheta_option0 : bestTheta_option1;
	return bestTheta; //[[ 1.0 / score, bestTheta], rmsALL];


}
+/

double[] calculate_geoLineFit_angle_withRMS(double [] x, double [] y , double theta_res = 1 * PI /180.00 , double rho_res = 100) {

	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0.00001;
	double theta_max = PI+0.00001;
	double rho_min   = 0.1/150000;


	double xDiff     = x.maxElement - x.minElement;
	double yDiff     = y.maxElement - y.minElement;

	double xDiff_seq = x[$-1] - x[0];
	double yDiff_seq = y[$-1] - y[0];


	int cnt = to!int(x.length);																				// y.length is the same




	double rho_max   = sqrt ( xDiff * xDiff + yDiff * yDiff ) / 2.0 ;										// half diagonal picked

	double xOrigin = xDiff / 2.0 + x.minElement;
	double yOrigin = yDiff / 2.0 + y.minElement;


	double bestTheta;


	double bestRho;
	double[] rmsALL = new double [] (0);

	double rho_diff  = rho_max - rho_min;


	for ( double theta = theta_min; theta <= theta_max; theta = theta + theta_res) {						// it can reach 2PI, thus <= is used and not just <

		double rho = rho_min;


		auto line_guess =[ theta, rho];																	// hesse normal form of a line as the tangent of a circle.

		auto m = tan (theta);																		// slope of the attempted hugh tangent line
		auto c = yOrigin - (m * xOrigin);					// c of y = mx + c


		double RMSE = 0;
		double tempScore = 0;

		double [] allErr = new double [] (0);
		for (int xi = 0; xi < cnt; xi++) {

			auto currPnt = [ x[xi], y[xi]];																// picked the point

			double t1 = m * currPnt[0];																	// m*x
			double t2 = currPnt[1];																		// y
			double t3 = c;																				// c
			double t4 = sqrt ( 1 + m*m);																// sqrt of 1 + m^2

			double dist = abs ( ( t1  - t2 + t3) / t4);
			allErr ~= dist;
			RMSE = RMSE + dist;
		}

		tempScore = 1.0 / RMSE;																			// total score after ALL points

		if ( tempScore > score) {

			score = tempScore;
			bestTheta = theta;
			bestRho   = rho;
			rmsALL    = allErr.gdup;
		}

	}



	// now need to check if theta is correctly aligned ....




	double bestTheta_check  = atan2(yDiff_seq, xDiff_seq);													// get the large direction



	if (bestTheta_check ==    0 && bestTheta ==    0 ) bestTheta = bestTheta;
	if (bestTheta_check ==    0 && bestTheta ==   PI ) bestTheta = bestTheta_check;
	if (bestTheta_check >     0 && bestTheta_check <   PI && bestTheta >  0 && bestTheta <  PI ) bestTheta = bestTheta;
	if (bestTheta_check <     0 && bestTheta_check >  -PI && bestTheta >  0 && bestTheta <  PI ) bestTheta = bestTheta-PI;
	if (bestTheta_check ==    PI && bestTheta ==   PI ) bestTheta = bestTheta_check;
	if (bestTheta_check ==    PI && bestTheta ==   PI ) bestTheta = bestTheta;


	/+

	double bestTheta_option0 = bestTheta;
	double bestTheta_option1 = (bestTheta + PI) % 2*PI;

	bestTheta = abs( bestTheta - bestTheta_option0) < abs( bestTheta - bestTheta_option1) ? bestTheta_option0 : bestTheta_option1;

	+/
																											// write("raw_guess is : ");writeln(bestTheta_check*180/PI);
																											// write("fitted guess is : ");writeln(bestTheta*180/PI);

	return [bestTheta_check, 1.0/score]; //[[ 1.0 / score, bestTheta], rmsALL];


}

double calculate_geoRMSError(double[] x, double [] y,double theta_res = 0.1 * PI /180.00 , double rho_res = 1.00 / 150000) {
	/+ +++++++++
	++ This function will return the heading of the best fit line
	++
	+/																			//writeln(x); writeln(y);

	/+
	double r;

	double xMean = mean(x);
	double yMean = mean(y);

	double denom = 0;
	double numer = 0;

	for( int i = 0; i < x.length; i++) {

		numer += (x[i] - xMean) * (y[i] - yMean);
		denom += (x[i] - xMean) * (x[i] - xMean);

	}

	double b1 = numer / denom ;
	double b0 = yMean - (b1 * xMean);											//writeln(b1); writeln(b0);


	double RMSE = 0;

	for ( int i = 0; i < x.length; i++) {
		double y_pred = b0 + b1 * x[i];
		RMSE += (y[i] - y_pred) ^^ 2;

	}

	r = sqrt(RMSE / x.length);

	return r;
	+/


	/+ +++++++++
	++ This function will return the heading of the best fit line and the RMS error
	++ uses hough transform
	++ angle resolution = 0.1 degrees
	++ distance resolution = ~ 1 meter
	+/


	double score = -9999;
	double theta_min = 0;
	double theta_max = 2*PI;
	double rho_min   = 0.1/150000;


	double xDiff     = x.maxElement - x.minElement;
	double yDiff     = y.maxElement - y.minElement;


	int cnt = to!int(x.length);																				// y.length is the same




	double rho_max   = sqrt ( xDiff * xDiff + yDiff * yDiff ) / 2.0 ;										// half diagonal picked

	double xOrigin = xDiff / 2.0 + x.minElement;
	double yOrigin = yDiff / 2.0 + y.minElement;


	double bestTheta;


	double bestRho;
	double[] rmsALL = new double [] (0);

	for ( double theta = theta_min; theta <= theta_max; theta = theta + theta_res) {						// it can reach 2PI, thus <= is used and not just <

		for ( double rho = rho_min; rho <= rho_max; rho = rho + rho_res) {


			auto line_guess =[ theta, rho];																	// hesse normal form of a line as the tangent of a circle.

			auto m = -1 / tan (theta);																		// slope of the attempted hugh tangent line
			auto c = ( yOrigin + rho * sin(theta)) - (m * (xOrigin + rho * cos(theta)));					// c of y = mx + c


			double RMSE = 0;
			double tempScore = 0;

			double [] allErr = new double [] (0);
			for (int xi = 0; xi < cnt; xi++) {

				auto currPnt = [ x[xi], y[xi]];																// picked the point

				double t1 = m * currPnt[0];																	// m*x
				double t2 = currPnt[1];																		// y
				double t3 = c;																				// c
				double t4 = sqrt ( 1 + m*m);																// sqrt of 1 + m^2

				double dist = abs ( ( t1  - t2 + t3) / t4);
				allErr ~= dist;
				RMSE = RMSE + dist;
			}

			tempScore = 1.0 / RMSE;																			// total score after ALL points

			if ( tempScore > score) {

				score = tempScore;
				bestTheta = theta;
				bestRho   = rho;
				rmsALL    = allErr.gdup;
			}
		}

	}



	// now need to check if theta is correctly aligned ....



	/+
	bestTheta_check  = atan2(yDiff, xDiff);														// get the large direction

	bestTheta_option0 = bestTheta;
	bestTheta_option1 = (bestTheta + PI) % 2*PI

	bestTheta = abs( bestTheta - bestTheta_option0) < abs( bestTheta - bestTheta_option1) ? bestTheta_option0 : bestTheta_option1;
	+/

	return  1.0 / score;




}

double calculate_lineDistance(field.line l1, field.line l2) {

	
	
	
	double a =  calculate_geoDistance((l1.startLat + l1.endLat) / 2.0 , l2.startLat, (l1.startLon + l1.endLon)/2.0 , l2.startLon);
	double b =  calculate_geoDistance((l1.startLat + l1.endLat) / 2.0 , l2.endLat, (l1.startLon + l1.endLon)/2.0 , l2.endLon);
	double c =  calculate_geoDistance((l2.startLat + l2.endLat) / 2.0 , l1.startLat, (l2.startLon + l2.endLon)/2.0 , l2.startLon);
	double d =  calculate_geoDistance((l2.startLat + l2.endLat) / 2.0 , l1.endLat, (l2.startLon + l2.endLon)/2.0 , l2.endLon);
	
	return min(a,b,c,d);

}

double calculate_geoCrossTrackdistance(double lat1, double lat2, double lat3, double lon1, double lon2, double lon3) {

	double deltaPhi, deltaLmb, deltaSE, deltaST, thetaA, thetaB, thetaSE, thetaES, thetaST, thetaET;								
																				// deltaSE = delta start end = delta12 in https://www.movable-type.co.uk/scripts/latlong.html
																				// deltaST = delta start third=delta13 in ditto
	double d = 0;																// cross track between LATLON 1&2 and LATLON 3
	
	deltaPhi = (lat2-lat1) * PI / 180.00;
	deltaLmb = (lon2-lon1) * PI / 180.00;
	
	deltaST = calculate_geoDistance(lat1, lat3, lon1, lon3) / 6400000.00;
	thetaST = calculate_geoBearing(lat1, lat3, lon1, lon3);	
	thetaSE = calculate_geoBearing(lat1, lat2, lon1, lon2);//write("bearing in radian SE: ");writeln(thetaST);
	
	
	d = asin ( sin (deltaST) * sin (thetaST - thetaSE)) * 6400000;
	
	return abs(d);
}

double calculate_geoBearing(double lat1, double lat2, double lon1, double lon2) {

	lat1 = lat1 * PI / 180.00;
	lat2 = lat2 * PI / 180.00;
	lon1 = lon1 * PI / 180.00;
	lon2 = lon2 * PI / 180.00;
	
	double deltaLambda = (lon2 - lon1);
	double y = sin( deltaLambda) * cos (lat2);
	double x = cos (lat1) * sin (lat2) - sin (lat1) * cos (lat2) * cos(deltaLambda);

	//return (atan2(y,x) + PI ) % PI ;//((( * 180.00 / PI ) + 360) % 360) * PI / 180.00;


	return acos(sin(lat1)*sin(lat2)+cos(lat1)*cos(lat2)*cos(lon2-lon1))*6371000;



}

double calculate_geoDistance_betweenLines(double lat1, double lat2, double lat3, double lat4, double lon1, double lon2, double lon3, double lon4) {

	
	auto d1 = calculate_geoDistance(lat1,lat3, lon1,lon3);//calculate_geoCrossTrackdistance(lat1, lat2, lat3, lon1, lon2, lon3);
	auto d2 = calculate_geoDistance(lat1,lat4, lon1,lon4);//calculate_geoCrossTrackdistance(lat1, lat2, lat4, lon1, lon2, lon4);
	auto d3 = calculate_geoDistance(lat2,lat3, lon2,lon3);//calculate_geoCrossTrackdistance(lat3, lat4, lat1, lon3, lon4, lon1);
	auto d4 = calculate_geoDistance(lat2,lat4, lon2,lon4);//calculate_geoCrossTrackdistance(lat3, lat4, lat2, lon3, lon4, lon2);
																				// writeln([d1,d2,d3,d4, to!int(min(abs(d1) , abs(d2) , abs(d3) , abs(d4)) < 40)]);
	return ( min(abs(d1) , abs(d2) , abs(d3) , abs(d4))) ; // / 4.00;
}

double [] calculate_geoArcIntersection( double[][] e1, double[][] e2) {
	auto a1 = e1[1][1] - e1[0][1];
	auto b1 = e1[0][0] - e1[1][0];
	auto c1 = a1 * e1[0][0] + b1* e1[0][1];
	
	auto a2 = e2[1][1] - e2[0][1];
	auto b2 = e2[0][0] - e2[1][0];
	auto c2 = a2 * e2[0][0] + b2* e2[0][1];
	
	auto delta = a1 * b2 - b1 * a2 ;
	
	auto p = [(b2 * c1 - b1 * c2) / delta, (c2 * a1 - c1 * a2) / delta ];
	
	return p;
	
}
	
string toStringLikeInCSharp(double value) {
  import std.format : format;
  return format("%.15G", value);
}
	
bool compare_Arrays(double[] a, double[] b) {

	if(a.length != b.length) return false;
	
	bool r = true;
	
	for(int i = 0; i < a.length; i ++) {
	
		r = r && isClose(a[i], b[i]);
	
	}
	
	return r;

}

bool canFind_inArray(double[][] a, double[] b) {

	if(a.length == 0) return false;
	
	bool r = true;
	
	for(int i = 0; i < a.length; i ++) {
	
	
		r = r && compare_Arrays(a[i], b);										//print_highPrecisionArray(a[i]);print_highPrecisionArray(b);
																				//writeln(r);
		if (r) break;
	}
	
	return r;

}

void print_highPrecisionArray(double [] a) {

	write("[");
	int i;
	for(i = 0; i < a.length -1 ; i++) write( toStringLikeInCSharp(a[i]) ~ ",");
	
	write( toStringLikeInCSharp(a[i]) ~ ",");
	
	writeln("]");
}

double [][] extendedUnique ( double [][] dAr) {

	double [][] res = new double [][] (0,0);
	
	res ~= dAr[0];
	
	for (int i = 1; i < dAr.length; i++) {
	
		bool found = false;
		
		foreach( r; res) {
		
			if (compare_Arrays ( r, dAr[i])) { // they are the same 
				found = true;
				break;
			}
		}
		
		if (! found) res~= dAr[i];
	
	}

	return res;
}

double [] calculate_geoNormal( double[] sourceP, double[] targetLine0, double[] targetLine1) {

	double [] r = new double[] (0);


	auto x1 = targetLine0[1];
	auto x2 = targetLine1[1];

	auto y1 = targetLine0[0];
	auto y2 = targetLine1[0];

	auto x3 = sourceP[1];
	auto y3 = sourceP[0];

	auto px = x2 - x1;
	auto py = y2 - y1;

	auto dAB = px * px + py * py;
	auto u =  ( ( x3 - x1) * px + (y3 - y1) * py ) / dAB;

	auto x = x1 + u * px ;
	auto y = y1 + u * py ;

	r = [ y, x];																// everything is flipppppppped, because lat / lon is y / x ...


	return r;

}

double [] extend_geoNormal( double[] targetLine0, double[] targetLine1) {

	double [] r = new double[] (0);


	auto x1 = targetLine0[1];
	auto x2 = targetLine1[1];

	auto y1 = targetLine0[0];
	auto y2 = targetLine1[0];


	auto u = [ y2 - y1 , x1 - x2];			//write("t1 :"); writeln(u);
	r = u.gdup;

	r[] = u[] / sqrt ( (u[0] * u[0]) + u[1] * u[1]);//write("t2 :"); writeln(r);
	return r;

}

bool check_intersect_withinLines( double[][] l0, double [][] l1) {

	double [] p1 = l0[0];					//writeln(p1);
	double [] p2 = l0[1];					//writeln(p2);

	double [] p3 = l1[0];					//writeln(p3);
	double [] p4 = l1[1];					//writeln(p4);

	double x1 = p1[0];
	double y1 = p1[1];

	double x2 = p2[0];
	double y2 = p2[1];

	double x3 = p3[0];
	double y3 = p3[1];

	double x4 = p4[0];
	double y4 = p4[1];



	double t = ( (x1 - x3 )* (y3 -y4) - (y1-y3) * (x3 - x4) ) / ( (x1 - x2 )* (y3 -y4) - (y1-y2) * (x3 - x4) );
	double u = ( (x2 - x1 )* (y1 -y3) - (y2-y1) * (x1 - x3) ) / ( (x1 - x2 )* (y3 -y4) - (y1-y2) * (x3 - x4) );

	bool r;

	if ( t > 0 && t < 1 && u > 0 && u < 1) r = true;
	else r = false;																							//if(r ) {writeln("returning true : "); // // readln;}

	return r;

}

bool check_intersect_closetoLines( double[][] l0, double [][] l1) {

	double [] p1 = l0[0];					//writeln(p1);
	double [] p2 = l0[1];					//writeln(p2);

	double [] p3 = l1[0];					//writeln(p3);
	double [] p4 = l1[1];					//writeln(p4);

	double x1 = p1[0];
	double y1 = p1[1];

	double x2 = p2[0];
	double y2 = p2[1];

	double x3 = p3[0];
	double y3 = p3[1];

	double x4 = p4[0];
	double y4 = p4[1];



	double t = ( (x1 - x3 )* (y3 -y4) - (y1-y3) * (x3 - x4) ) / ( (x1 - x2 )* (y3 -y4) - (y1-y2) * (x3 - x4) );
	double u = ( (x2 - x1 )* (y1 -y3) - (y2-y1) * (x1 - x3) ) / ( (x1 - x2 )* (y3 -y4) - (y1-y2) * (x3 - x4) );

	bool r;

	if ( t > 0 && t < 1 && u > 0 && u < 1) r = true;
	else r = false;																							//if(r ) {writeln("returning true : "); // // readln;}

	return r;

}

void print_highPrecision_geoArray(double [] a) {

	write("[");
	int i;
	for(i = 0; i < a.length -1 ; i++) write( toStringLikeInCSharp(a[i]) ~ ",");

	write( toStringLikeInCSharp(a[i]) ~ "," ~ to!string(i) ~ " , #00ff00" );

	writeln("]");
}
