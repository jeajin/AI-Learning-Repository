obj = findobj(gcf,'Type','line');
glucose = [];

for i = 1:length(obj)
    lineGraph = get(obj(i,1));
    lineName = lineGraph.DisplayName;
 
    glucose = lineGraph.YData;
end
glucose = glucose'
filename = "M_adult005.xlsx";
writematrix(glucose,filename, 'sheet', 1 , 'Range','A1')
