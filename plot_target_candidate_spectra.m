function plot_target_candidate_spectra(spectra,summary,outdir,unit)
% Diagnostic presentation only: identical target marker in R=2,3,4 panels.
fig=figure('Visible','off','Color','w','Units','inches', ...
    'Position',[0.5 0.5 11 12]);
layout=tiledlayout(fig,3,1,'TileSpacing','loose','Padding','loose');
for R=2:4
    ax=nexttile(layout);
    c=summary.candidates(R-1);
    if isempty(spectra{R-1})
        text(0.5,0.5,c.reason,'HorizontalAlignment','center', ...
            'Units','normalized');
        title(sprintf('R=%d: no spectrum',R));
        continue;
    end
    s=spectra{R-1};
    if strcmp(unit,'order')
        target=c.theoretical_order; peak=c.target_peak_order;
        back=s.axis>=0.5 & s.axis<=12 & ...
            ~(s.axis>=0.8*target & s.axis<=1.2*target);
        axisLabel='Repetition order (cycles/revolution)';
        upper=ceil(3.5*target);
    else
        target=c.theoretical_hz; peak=c.target_peak_hz;
        back=s.axis>=50 & s.axis<=200 & ...
            ~(s.axis>=0.8*target & s.axis<=1.2*target);
        axisLabel='Repetition frequency (Hz)';
        upper=50*ceil(3.5*target/50);
    end
    rawDb=10*log10(s.original_power/(median(s.original_power(back))+eps)+eps);
    fusedDb=10*log10(s.fused_power/(median(s.fused_power(back))+eps)+eps);
    h1=plot(s.axis,rawDb,'Color',[.42 .42 .42],'LineWidth',.9); hold on;
    h2=plot(s.axis,fusedDb,'b','LineWidth',1.0);
    h3=xline(target,'r--','LineWidth',0.9);
    if isfinite(peak)
        [~,idx]=min(abs(s.axis-peak));
        h4=plot(s.axis(idx),fusedDb(idx),'bo','MarkerFaceColor','b', ...
            'MarkerSize',6);
        legend([h1 h2 h3 h4],{'Original','Fused', ...
            ['Theoretical ' summary.target_hypothesis],'Located peak'}, ...
            'Location','southeast','FontSize',8);
    else
        legend([h1 h2 h3],{'Original','Fused', ...
            ['Theoretical ' summary.target_hypothesis]}, ...
            'Location','southeast','FontSize',8);
    end
    xlim([0 upper]);
    shown=s.axis>0 & s.axis<=upper;
    visible=[rawDb(shown);fusedDb(shown)];
    visible=sort(visible(isfinite(visible)));
    lower=visible(max(1,ceil(0.02*numel(visible))));
    ylim([lower-5 visible(end)+10]);
    title(sprintf('R=%d | %s | J=%.3g | %s',R,summary.target_hypothesis, ...
        c.J,c.reason),'Interpreter','none');
    xlabel(axisLabel); ylabel('Periodic power / median (dB)');
    set(ax,'FontName','Arial','FontSize',9,'LineWidth',.8, ...
        'Box','on','TickDir','out');
    spectrum=table(s.axis(:),s.original_power(:),s.fused_power(:), ...
        'VariableNames',{'repetition_axis','original_power','fused_power'});
    writetable(spectrum,fullfile(outdir,sprintf('candidate_R%d_spectrum.csv',R)));
end
exportgraphics(fig,fullfile(outdir,'candidate_spectra.png'),'Resolution',300);
exportgraphics(fig,fullfile(outdir,'candidate_spectra.pdf'),'ContentType','vector');
close(fig);
end
